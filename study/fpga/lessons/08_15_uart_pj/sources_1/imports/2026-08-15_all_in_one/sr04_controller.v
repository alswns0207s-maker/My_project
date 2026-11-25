`timescale 1ns / 1ps

//=====================================================================
// sr04_controller  -  HC-SR04 컨트롤러 (이해를 돕기 위한 간소화 버전)
//
// 포트는 최소 구성(clk, reset, start, echo -> done, valid, trigger, distance)을
// 그대로 유지하고, 내부만 아래처럼 최대한 단순하게 짰다:
//   - 상태값은 0,1,2,3,4,5 처럼 그냥 작은 숫자로 둔다 (3'd0 같은 비트폭 표기 없이).
//   - "이전값과 비교"하는 edge 검출은 쓰지 않는다. echo는 tick_gen_1us가 만드는
//     tick_us와 cnt(카운터) 딱 두 가지로만 시간을 재고, 상태 전환은 echo 레벨을
//     그대로 확인한다 (WAIT_RISE/MEASURE는 한 번만 거쳐가는 상태라 레벨 체크만
//     으로도 충분하다 - 아래 "레벨 체크로 충분한 이유" 참고).
//   - 거리 계산은 MEASURE 안에서 같이 하지 않고 DISTANCE 상태를 따로 둬서 분리했다.
//   - 무응답 타임아웃, 2~400cm 범위 검증은 뺐다.
//     (실제 보드에 올릴 땐 타임아웃과 범위 검증이 있는 완전한 버전을 쓰는 편이
//      안전하다 — 이 버전은 동작 원리 설명용.)
//=====================================================================
module sr04_controller #(
    parameter integer TICK_1US = 100   // 1us 를 만드는 데 필요한 클럭 수 (100MHz 기준 100)
) (
    input            clk,
    input            reset,
    input            start,
    input            echo,
    output           done,
    output           valid,
    output           trigger,
    output     [8:0] distance
);

    // 상태: 0=IDLE, 1=TRIGGER, 2=WAIT_RISE(echo High 대기),
    //       3=MEASURE(echo Low 대기 + 폭 카운트), 4=DISTANCE(거리 계산), 5=FINISH
    localparam IDLE      = 0;
    localparam TRIGGER   = 1;
    localparam WAIT_RISE = 2;
    localparam MEASURE   = 3;
    localparam DISTANCE  = 4;
    localparam FINISH    = 5;

    reg [2:0]  state, state_next;
    reg [15:0] cnt, cnt_next;
    reg [8:0]  distance_reg, distance_next;
    reg        valid_reg, valid_next;

    // echo는 센서가 FPGA 클럭과 무관하게 바꾸는 비동기 신호라서, 플립플롭 2개로만
    // 동기화한다 (메타스테이블 방지 - 이건 "edge 검출"이 아니라 그냥 입력 안정화).
    // 이전 클럭 값과 비교하는 세 번째 레지스터는 두지 않는다.
    reg echo_s0, echo_s1;
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            echo_s0 <= 0;
            echo_s1 <= 0;
        end else begin
            echo_s0 <= echo;
            echo_s1 <= echo_s0;
        end
    end

    // ---- 레벨 체크로 충분한 이유 ----
    // WAIT_RISE는 TRIGGER 직후, echo가 아직 Low인 상태에서만 들어온다.
    // 그래서 "echo_s1==1 이 될 때까지" 그냥 기다리면 되고, High가 되는 순간
    // 바로 다음 상태(MEASURE)로 넘어가므로 같은 조건을 두 번 만날 일이 없다.
    // MEASURE도 마찬가지로 echo_s1==1 인 채로 들어와서 "echo_s1==0"이 될 때까지
    // 기다리는 구조라, 이전값과 비교하지 않아도 상태 자체가 "한 번만" 반응한다.

    wire tick_us;
    tick_gen_1us #(
        .F_COUNT(TICK_1US)
    ) U_TICK_GEN_1US (
        .clk     (clk),
        .reset   (reset),
        .run_stop(state != IDLE),
        .clear   (state == IDLE),
        .o_tick  (tick_us)
    );

    // 상태 레지스터 (다음-값 4개를 여기서 한꺼번에 붙잡는다 - state/cnt 뿐 아니라
    // distance/valid 도 같은 always 블록에서 <= 로만 처리하는 표준 2-블록 Moore FSM 형태)
    always @(posedge clk, posedge reset) begin
        if (reset) begin
            state        <= IDLE;
            cnt          <= 0;
            distance_reg <= 0;
            valid_reg    <= 0;
        end else begin
            state        <= state_next;
            cnt          <= cnt_next;
            distance_reg <= distance_next;
            valid_reg    <= valid_next;
        end
    end

    // 다음 상태 / 카운터 / 거리 계산 로직 - case 문 하나에서 전부 처리
    // (나눗셈은 여기서도 여전히 "조합논리"다. case 문 안이냐 밖이냐는 문법 위치일
    //  뿐, cnt/58 은 항상 조합 divider 로 합성되고 위 레지스터가 그 결과를 캡처한다.)
    always @(*) begin
        state_next    = state;
        cnt_next      = cnt;
        distance_next = distance_reg;   // 기본값: 유지 (DISTANCE 상태 아니면 그대로 홀드)
        valid_next    = valid_reg;

        case (state)
            IDLE: begin
                cnt_next = 0;
                if (start) begin
                    state_next    = TRIGGER;   // 새 측정 요청
                    distance_next = 0;         // 이전 결과부터 지운다
                    valid_next    = 0;
                end
            end

            TRIGGER: begin
                if (tick_us) begin
                    if (cnt == 10) begin
                        cnt_next   = 0;
                        state_next = WAIT_RISE;
                    end else begin
                        cnt_next = cnt + 1;
                    end
                end
            end

            WAIT_RISE: begin

                if (echo_s1 == 1'b1) begin
                    cnt_next   = 0;
                    state_next = MEASURE;
                end
            end
            MEASURE: begin
                if (tick_us) cnt_next = cnt + 1;
                if (echo_s1 == 1'b0) state_next = DISTANCE; 
            end
            DISTANCE: begin
                distance_next = cnt / 58;
                valid_next    = 1;
                state_next    = FINISH;
            end
            FINISH: begin
                state_next = IDLE;
            end

            default: state_next = IDLE;
        endcase
    end

    assign trigger  = (state == TRIGGER);
    assign done     = (state == FINISH);
    assign valid    = valid_reg;
    assign distance = distance_reg;

endmodule
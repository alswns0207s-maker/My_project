`timescale 1ns / 1ps
module axi_slave (
    input  logic        ACLK,
    input  logic        ARESETn,
    // 1. AW Channel (Write Address) - Slave
    input  logic [31:0] AWADDR,
    input  logic        AWVALID,
    output logic        AWREADY,
    // 2. W Channel (Write Data) - Slave 
    input  logic [31:0] WDATA,
    input  logic        WVALID,
    input  logic        WLAST,
    output logic        WREADY,
    // 3. B Channel (Write Response) - Slave
    output logic [ 1:0] BRESP,
    output logic        BVALID,
    input  logic        BREADY,
    // 4. AR Channel (Read Address) - Slave 
    input  logic [31:0] ARADDR,
    input  logic        ARVALID,
    output logic        ARREADY,
    // 5. R Channel (Read Data) - Slave
    output logic [31:0] RDATA,
    output logic        RVALID,
    output logic [ 1:0] RRESP,
    input  logic        RREADY
);
    logic [31:0] slv_reg0, slv_reg1, slv_reg2, slv_reg3;

    // 1. AW Channel FSM
    typedef enum logic {
        AW_IDLE  = 1'b0,
        AW_VALID = 1'b1
    } aw_state_e;

    aw_state_e aw_state, aw_state_next;

    always_ff @(posedge ACLK) begin
        if (!ARESETn) begin
            aw_state <= AW_IDLE;
        end else begin
            aw_state <= aw_state_next;
        end
    end

    always_comb begin
        aw_state_next = aw_state;
        AWREADY       = 1'b0;

        case (aw_state)
            AW_IDLE: begin
                AWREADY = 1'b0;
                if (AWVALID) begin
                    aw_state_next = AW_VALID;
                end
            end
            AW_VALID: begin
                AWREADY = 1'b1;
                if (AWVALID && AWREADY) begin
                    aw_state_next = AW_IDLE;
                end
            end
            default: aw_state_next = AW_IDLE;`
        endcase
    end

    // 2. W Channel FSM

    typedef enum logic {
        W_IDLE  = 1'b0,
        W_VALID = 1'b1
    } w_state_e;

    w_state_e w_state, w_state_next;


    always_ff @(posedge ACLK) begin
        if (!ARESETn) begin
            w_state <= W_IDLE;
        end else begin
            w_state <= w_state_next;
        end
    end

    always_comb begin
        w_state_next = w_state;
        WREADY       = 1'b0;

        case (w_state)
            W_IDLE: begin
                WREADY = 1'b0;
                if (WVALID) begin
                    w_state_next = W_VALID;
                end
            end
            W_VALID: begin
                WREADY = 1'b1;
                // WLAST 신호까지 고려하여 데이터 전송 완료 처리
                if (WVALID && WREADY) begin
                    w_state_next = W_IDLE;
                end
            end
            default: w_state_next = W_IDLE;
        endcase
    end

    // 3. B Channel FSM
    typedef enum logic {
        B_IDLE  = 1'b0,
        B_VALID = 1'b1
    } b_state_e;

    b_state_e b_state, b_state_next;

    always_ff @(posedge ACLK) begin
        if (!ARESETn) begin
            b_state <= B_IDLE;
        end else begin
            b_state <= b_state_next;
        end
    end

    always_comb begin
        b_state_next = b_state;
        BVALID       = 1'b0;
        BRESP        = 2'b00;  // OKAY

        case (b_state)
            B_IDLE: begin
                BVALID = 1'b0;
                if (WVALID && WREADY) begin
                    b_state_next = B_VALID;
                end
            end
            B_VALID: begin
                BVALID = 1'b1;
                BRESP  = 2'b00;  // OKAY Response
                if (BVALID && BREADY) begin
                    b_state_next = B_IDLE;
                end
            end
            default: b_state_next = B_IDLE;
        endcase
    end

    // 4. AR Channel FSM 

    typedef enum logic {
        AR_IDLE  = 1'b0,
        AR_VALID = 1'b1
    } ar_state_e;

    ar_state_e ar_state, ar_state_next;

    always_ff @(posedge ACLK) begin
        if (!ARESETn) begin
            ar_state <= AR_IDLE;
        end else begin
            ar_state <= ar_state_next;
        end
    end

    always_comb begin
        ar_state_next = ar_state;
        ARREADY       = 1'b0;

        case (ar_state)
            AR_IDLE: begin
                ARREADY = 1'b0;
                if (ARVALID) begin
                    ar_state_next = AR_VALID;
                end
            end
            AR_VALID: begin
                ARREADY = 1'b1;
                if (ARVALID && ARREADY) begin
                    ar_state_next = AR_IDLE;
                end
            end
            default: ar_state_next = AR_IDLE;
        endcase
    end

    // 5. R Channel FSM (Sequential & Combinational)

    typedef enum logic {
        R_IDLE  = 1'b0,
        R_VALID = 1'b1
    } r_state_e;

    r_state_e r_state, r_state_next;

    always_ff @(posedge ACLK) begin
        if (!ARESETn) begin
            r_state <= R_IDLE;
        end else begin
            r_state <= r_state_next;
        end
    end

    always_comb begin
        r_state_next = r_state;
        RVALID       = 1'b0;
        RDATA        = 32'h0;
        RRESP        = 2'b00;

        case (r_state)
            R_IDLE: begin
                RVALID = 1'b0;
                if (ARVALID && ARREADY) begin
                    r_state_next = R_VALID;
                end
            end
            R_VALID: begin
                RVALID = 1'b1;
                RDATA  = slv_reg0;
                RRESP  = 2'b00;
                if (RVALID && RREADY) begin
                    r_state_next = R_IDLE;
                end
            end
            default: r_state_next = R_IDLE;
        endcase
    end

endmodule

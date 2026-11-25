module axi_master (
    input  logic        ACLK,
    input  logic        ARESETn,
    // AW channel
    input  logic        AWREADY,
    output logic [31:0] AWADDR,
    output logic        AWVALID,
    // W channel
    input  logic        WREADY,
    output logic [31:0] WDATA,
    output logic        WVALID,
    // B channel
    input  logic [ 1:0] BRESP,
    input  logic        BVALID,
    output logic        BREADY,
    // AR channel
    input  logic        ARREADY,
    output logic [31:0] ARADDR,
    output logic        ARVALID,
    // R channel
    input  logic [31:0] RDATA,
    input  logic        RVALID,
    input  logic [ 1:0] RRESP,
    output logic        RREADY,
    // Host to Master (AXI4_Lite)
    input  logic        transfer,
    input  logic [31:0] addr,
    input  logic [31:0] wdata,
    input  logic        write,
    output logic        ready,
    output logic [31:0] rdata
);
    // 1. AW Channel FSM (Write Address)
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
        AWADDR        = 32'd0;
        AWVALID       = 1'b0;

        case (aw_state)
            AW_IDLE: begin
                AWVALID = 1'b0;
                if (transfer & write) begin
                    aw_state_next = AW_VALID;
                end
            end
            AW_VALID: begin
                AWADDR  = addr;
                AWVALID = 1'b1;
                if (AWREADY) begin
                    aw_state_next = AW_IDLE;
                end
            end
            default: begin
                aw_state_next = AW_IDLE;
            end
        endcase
    end

    // 2. W Channel FSM (Write Data)
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
        WDATA        = 32'd0;
        WVALID       = 1'b0;

        case (w_state)
            W_IDLE: begin
                WVALID = 1'b0;
                if (transfer & write) begin
                    w_state_next = W_VALID;
                end
            end
            W_VALID: begin
                WDATA  = wdata;
                WVALID = 1'b1;
                if (WREADY) begin
                    w_state_next = W_IDLE;
                end
            end
            default: begin
                w_state_next = W_IDLE;
            end
        endcase
    end

    // 3. B Channel FSM (Write Response)
    typedef enum logic {
        B_IDLE  = 1'b0,
        B_READY = 1'b1
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
        BREADY       = 1'b0;
        case (b_state)
            B_IDLE: begin
                BREADY = 1'b0;
                if (WVALID) begin
                    b_state_next = B_READY;
                end
            end

            B_READY: begin
                BREADY = 1'b1;
                if (BVALID && BREADY) begin
                    b_state_next = B_IDLE;
                end
            end

            default: begin
                b_state_next = B_IDLE;
            end
        endcase
    end

    // 4. AR Channel FSM (Read Address)
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
        ARADDR        = 32'd0;
        ARVALID       = 1'b0;

        case (ar_state)
            AR_IDLE: begin
                ARVALID = 1'b0;
                if (transfer && !write) begin
                    ar_state_next = AR_VALID;
                end
            end
            AR_VALID: begin
                ARADDR  = addr;
                ARVALID = 1'b1;
                if (ARREADY) begin
                    ar_state_next = AR_IDLE;
                end
            end
            default: begin
                ar_state_next = AR_IDLE;
            end
        endcase
    end

    // 5. R Channel FSM (Read Data)
    typedef enum logic {
        R_IDLE  = 1'b0,
        R_READY = 1'b1
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
        RREADY       = 1'b0;

        case (r_state)
            R_IDLE: begin
                RREADY = 1'b0;
                if (ARVALID) begin
                    r_state_next = R_READY;
                end
            end
            R_READY: begin
                RREADY = 1'b1;
                if (RVALID && RREADY) begin
                    r_state_next = R_IDLE;
                end
            end
            default: begin
                r_state_next = R_IDLE;
            end
        endcase
    end

    assign ready = write ? ((aw_state == AW_IDLE) && (w_state == W_IDLE) && (b_state == B_IDLE) && transfer)
                         : ((ar_state == AR_IDLE) && (r_state == R_READY) && RVALID && RREADY);
                         
    assign rdata = RDATA;

endmodule
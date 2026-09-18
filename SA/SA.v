module SA(
	// Input signals
	clk,
	rst_n,
	in_valid,
	T,
	in_data,
	w_Q,
	w_K,
	w_V,
	// Output signals
	out_valid,
	out_data
);

input clk;
input rst_n;
input in_valid;
input [3:0] T;
input signed [7:0] in_data;
input signed [7:0] w_Q;
input signed [7:0] w_K;
input signed [7:0] w_V;

output reg out_valid;
output reg signed [31:0] out_data;

//FSM declare
localparam IDLE = 2'b00;
localparam LOAD = 2'b01;
localparam CALC = 2'b10;
localparam OUT  = 2'b11;

reg [1:0]state, nxt_state;

//input store
reg signed [7:0]r_in_data[0:7][0:7];
reg signed [7:0]r_w_Q[0:7][0:7];
reg signed [7:0]r_w_K[0:7][0:7];
reg signed [7:0]r_w_V[0:7][0:7];
reg [3:0]r_T;

//counter declare
reg [5:0]data_cnt;
reg [7:0]weight_cnt;
reg [31:0]calc_result;
reg data_done;

//handshake wire
wire data_last = (data_cnt[5:3] == r_T - 1'b1) && (data_cnt[2:0] == 3'd7);
// wire w_Q_done = weight_cnt == 63;
// wire w_K_done = weight_cnt == 127;
wire w_V_done = weight_cnt == 191;
wire load_done = (state == LOAD) && in_valid && (weight_cnt =='d191);
wire calc_done = 1'b0; 
wire out_done = 1'b0;


//FSM
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        state <= IDLE;
    end
    else begin
        state <= nxt_state;
    end
end


//FSM control
always@(*)begin
    case(state)
    IDLE :
        nxt_state = in_valid ? LOAD : IDLE;
    LOAD :
        nxt_state = load_done ? CALC : LOAD;
    CALC :
        nxt_state = calc_done ? OUT : CALC;
    OUT  :
        nxt_state = out_done ? IDLE : OUT;
    default : 
        nxt_state = IDLE;
    endcase
end


//data cnt
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        data_cnt <= 'd0;
    end
    else begin
        if(state ==IDLE)begin
            if(in_valid)begin
                data_cnt <= 'd1;
            end
            else begin
                data_cnt <= 'd0;
            end
        end
        else if(state == LOAD)begin
            if(in_valid && !data_last)begin
                data_cnt <= data_cnt + 'd1;
            end
        end
        else begin
            data_cnt <= 'd0;
        end
    end
end


//weight cnt
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        weight_cnt <= 'd0;
    end
    else begin
        if(state == IDLE)begin
            if(in_valid)begin
                weight_cnt <= 'd1;
            end
            else begin
                weight_cnt <= 'd0;
            end
        end
        else if(state == LOAD)begin
            if(in_valid && !w_V_done)begin
                weight_cnt <= weight_cnt +'d1;
            end
        end
        else begin
            weight_cnt <= 'd0;
        end
    end
end


//T register
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        r_T <= 'd0;
    end
    else begin
        if(state == IDLE && in_valid)begin
            r_T <= T;
        end
    end
end


//in_data register
always@(posedge clk )begin
    if(in_valid)begin
        if(state == IDLE)begin
            r_in_data[0][0] <= in_data;
        end
        else if(state == LOAD && !data_done)begin
            r_in_data[data_cnt[5:3]][data_cnt[2:0]] <= in_data;
        end
    end
end

//store w_Q
always@(posedge clk )begin
    if(in_valid)begin
        if(state == IDLE)begin
            r_w_Q[0][0] <= w_Q;
        end
        else if(state == LOAD && weight_cnt[7:6]==2'b00)begin
            r_w_Q[weight_cnt[5:3]][weight_cnt[2:0]] <= w_Q;
        end
    end
end

//store w_K
always@(posedge clk)begin
    if(in_valid && state == LOAD && weight_cnt[7:6]==2'b01)begin
        r_w_K[weight_cnt[5:3]][weight_cnt[2:0]] <= w_K;
    end
end

//store w_V
always@(posedge clk)begin
    if(in_valid && state == LOAD && weight_cnt[7:6]==2'b10)begin
        r_w_V[weight_cnt[5:3]][weight_cnt[2:0]] <= w_V;
    end
end

//data_done
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        data_done <= 1'b0;
    end
    else begin
        if(state == IDLE && in_valid)begin
            data_done <= 1'b0;
        end
        else if(state == LOAD && in_valid && data_last)begin
            data_done <= 1'b1;
        end
        else if(state != LOAD)begin
            data_done <= 1'b0;
        end
    end
end 

//output block
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
        out_valid <= 'd0;
    end
    else begin
        if(state == OUT)begin
            out_valid <= 'd1;
        end
        else begin
            out_valid <= 'd0;
        end
    end
end


always @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin
        out_data <= 'd0;
    end
    else begin
        if(state == OUT)begin
            out_data <= calc_result;
        end
        else begin
            out_data <= 'd0;
        end
    end
end


endmodule
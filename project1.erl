%SHIVAM GUPTA
%CAROLINE FEDELE
-module(project1).

% String in Erlang - This module provides functions for string processing.
-import(string, [substr/3]).

% cpu_sup in Erlang - A CPU Load and CPU Utilization Supervisor Process
-import(cpu_sup, [bitcoin_miner/0, stop/0, util/0]).

% Function Calls
-export([start_master/2, start_worker/1, for/3, for_worker/2, master/2, worker/2, loop_string/2, bitcoin_miner/3, wunit/3, pend/0]).

%----------------------------------------SPAWN WORKERS CODE-----------------------------------------------
for(0, _, _) ->
    ok;
for(Num, Master_Node, Input) ->
    V = "Master",
    spawn(project1, bitcoin_miner, [Master_Node, Input, V]),
    for(Num - 1, Master_Node, Input).

% For loop for spawning workers for the master to mine the bitcoins
for_worker(0, _) ->
    ok;
for_worker(Num, Master_Node) ->
    spawn(project1, worker, [1, Master_Node]),
    for_worker(Num - 1, Master_Node).

%----------------------------------------MASTER CODE-----------------------------------------------------

start_master(Master_Node, Input) ->
    register(mid, spawn(project1, master, [Master_Node, Input])),
    for(10, Master_Node, Input).

master(Master_Node, Input) ->
    receive
        {Ch, RandStr, Id, Var} ->
            % Hash, Str2, self(), Var
            % Message received by the master to be printed as output.
            io:fwrite("~p with ID ~p\t Found Coin  ~p\t ~p\n", [Var, Id, RandStr, Ch]);

        {_Pid, Msg} ->
            if
                Msg == requestwork ->
                    % The workers requesting the master for worker
                    _Pid ! {self(), startwork, Input};
                true ->
                    ok
            end
    end,
    master(Master_Node, Input).

%---------------------------------------------WORKER CODE----------------------------------------------
 % Start point for the statistics function to compute Ratio of CPU and Real Time to compute Parallelism
start_worker(Master_Node) ->
    statistics(runtime),
    statistics(wall_clock),
    persistent_term:put(t, 10),
    for_worker(10, Master_Node).

%-----Function to determine the statistics at the Program End-----
pend() ->
    {_, Time1} = statistics(runtime),
    {_, Time2} = statistics(wall_clock),
    U1 = Time1 * 1000,
    U2 = Time2 * 1000,
    io:format(
        "Code time=~p (~p) microseconds~n",
        [U1, U2]
    ),
    io:format("Ratio [CPU Time:Real Time]= ~p",[U1/U2]).

wunit(0, _, _) ->
    stopped;
wunit(N, Master_Node, NumZ) ->
    V = "Worker",
    bitcoin_miner(Master_Node, NumZ, V),
    wunit(N - 1, Master_Node, NumZ).

worker(0, _) ->
    ok;
worker(N, Master_Node) ->
    {mid, Master_Node} ! {self(), requestwork},

    receive
        {From, Msg, Input} ->
            if
                Msg == startwork ->
                    io:fwrite("Starting work for Master_Node ~p",[From]),

                    %Assignment of Work Units
                    wunit(10, Master_Node, Input),
                    io:fwrite("."),
                    Val = persistent_term:get(t),
                    persistent_term:put(t, Val - 1);
                % From ! {self(), donework};
                true ->
                    ok
            end;
        stop ->
            ok
    end,
    G = persistent_term:get(t),
    if
        G == 0 ->
            pend();
        true ->
            worker(N - 1, Master_Node)
    end.

%---------------------------------------CODE FOR GENERATING BITCOIN-----------------------------------------

% Loop to get number of zeroes in string formfrom the single digit integer input.
loop_string(0, Str) ->
    Str;
loop_string(N, Str) ->
    S = Str ++ "0",
    loop_string(N - 1, S).

bitcoin_miner(Master_Node, Zeros_required, Var) ->
    
    %Random String generated using crypto module Generates N bytes randomly uniform 0..255, 
    %and returns the result in a binary. Uses a cryptographically secure prng seeded and periodically 
    %mixed with operating system provided entropy. By default this is the RAND_bytes method from OpenSSL.
    Str1 = binary_to_list(base64:encode(crypto:strong_rand_bytes(10))),
    
    % String 1 for UFID
    %Str2 = "cfedele"
    Str2 = "shivamgupta1" ++ Str1,

    %binary:decode_unsigned/1 decodes the whole binary as one large big-endian unsigned integer.
    %Hash256 (Note that <<Integer:256>> is equivalent to <<Integer:256/big-unsigned-integer>> since those are the default flags).
    Hash = io_lib:format("~64.16.0b", [binary:decode_unsigned(crypto:hash(sha256, Str2))]),
    
    %Leading Number of Zeroes converted from integer to string 
    ZeroVar = loop_string(Zeros_required, ""),

    %Leading number of zeroes being searched in the string
    Bool = string:find(Hash, ZeroVar) =:= Hash,

    if
        Bool == true ->
            K = substr(Hash, Zeros_required + 1, 1),
            if
                K /= "0" ->
                    {mid, Master_Node} ! {Hash, Str2, self(), Var};
                true ->
                    % Output sent to Master to Print Output
                    bitcoin_miner(Master_Node, Zeros_required, Var)
            end;
        true ->
            % Recursion if coin not found
            bitcoin_miner(Master_Node, Zeros_required, Var)
    end.

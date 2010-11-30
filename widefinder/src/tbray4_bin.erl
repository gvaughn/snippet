-module(tbray4_bin).

-compile([native]).

-export([start/1,
         start/2]).

-include_lib("kernel/include/file.hrl").

%% erl -smp
%% timer:tc(tbray, start, ["o1000k.ap", 10]).
start([FileName, ProcNum]) when is_list(ProcNum) -> 
    start(FileName, list_to_integer(ProcNum)).
start(FileName, ProcNum) ->
    Start = now(),

    Main = self(),
    Counter = spawn(fun () -> count_loop(Main) end),
    Collector = spawn(fun () -> collect_loop(Counter) end),

    pread_file(FileName, ProcNum, Collector),

    %% don't terminate, wait here, until all tasks done.
    receive
        stop -> io:format("Time: ~10.2f ms~n", [timer:now_diff(now(), Start) / 1000])       
    end.

pread_file(FileName, ProcNum, Collector) ->
    ChunkSize = get_chunk_size(FileName, ProcNum),
    pread_file_1(FileName, ChunkSize, ProcNum, Collector).       
pread_file_1(FileName, ChunkSize, ProcNum, Collector) ->
    [spawn(fun () ->
                   Length = if  I == ProcNum - 1 -> ChunkSize * 2; %% lastest chuck
                                true -> ChunkSize end,
                   {ok, File} = file:open(FileName, [read, binary]),
                   {ok, Bin} = file:pread(File, ChunkSize * I, Length),
                   file:close(File),
                   {Data, Tail} = split_on_last_newline(Bin),
                   Collector ! {seq, I, Data, Tail}
           end) || I <- lists:seq(0, ProcNum - 1)],
    Collector ! {chunk_num, ProcNum}.

read_file(FileName, ProcNum, Collector) ->
    ChunkSize = get_chunk_size(FileName, ProcNum),
    {ok, File} = file:open(FileName, [raw, binary]),
    read_file_1(File, ChunkSize, 0, Collector).    
read_file_1(File, ChunkSize, I, Collector) ->
    case file:read(File, ChunkSize) of
        eof ->
            file:close(File),
            Collector ! {chunk_num, I};
        {ok, Bin} -> 
            spawn(fun () ->
                          {Data, Tail} = split_on_last_newline(Bin),
                          Collector ! {seq, I, Data, Tail}
                  end),
            read_file_1(File, ChunkSize, I + 1, Collector)
    end.

collect_loop(Counter) -> collect_loop_1([], <<>>, -1, Counter).
collect_loop_1(Chunks, PrevTail, LastSeq, Counter) ->
    receive
        {chunk_num, ChunkNum} ->
            Counter ! {chunk_num, ChunkNum},
            collect_loop_1(Chunks, PrevTail, LastSeq, Counter);
        {seq, I, Data, Tail} ->
            SortedChunks = lists:keysort(1, [{I, Data, Tail} | Chunks]),
            {Chunks1, PrevTail1, LastSeq1} = 
                process_chunks(SortedChunks, [], PrevTail, LastSeq, Counter),
            collect_loop_1(Chunks1, PrevTail1, LastSeq1, Counter)
    end.
    
count_loop(Main) -> count_loop_1(Main, dict:new(), undefined, 0).
count_loop_1(Main, Dict, ChunkNum, ChunkNum) ->
    print_result(Dict),
    Main ! stop;
count_loop_1(Main, Dict, ChunkNum, ProcessedNum) ->
    receive
        {chunk_num, ChunkNumX} -> 
            count_loop_1(Main, Dict, ChunkNumX, ProcessedNum);
        {dict, DictX} ->
            Dict1 = dict:merge(fun (_, V1, V2) -> V1 + V2 end, Dict, DictX),
            count_loop_1(Main, Dict1, ChunkNum, ProcessedNum + 1)
    end.

process_chunks([], ChunkBuf, PrevTail, LastSeq, _) -> {ChunkBuf, PrevTail, LastSeq};
process_chunks([{I, Data, Tail}=Chunk|T], ChunkBuf, PrevTail, LastSeq, Counter) ->
    case LastSeq + 1 of
        I ->
            spawn_opt(fun () -> Counter ! {dict, scan_chunk(<<PrevTail/binary, Data/binary>>)} end, [{min_heap_size, 3000}]),
            process_chunks(T, ChunkBuf, Tail, I, Counter);
        _ ->
            process_chunks(T, [Chunk | ChunkBuf], PrevTail, LastSeq, Counter)
    end.

print_result(Dict) ->
    SortedList = lists:reverse(lists:keysort(2, dict:to_list(Dict))),
    [io:format("~b\t: ~s~n", [V, K]) || {K, V} <- lists:sublist(SortedList, 10)].

get_chunk_size(FileName, ProcNum) ->
    {ok, #file_info{size=Size}} = file:read_file_info(FileName),
    Size div ProcNum.

split_on_last_newline(Bin) -> split_on_last_newline_1(Bin, size(Bin)).   
split_on_last_newline_1(Bin, Offset) when Offset > 0 ->
    case Bin of
        <<Data:Offset/binary,$\n,Tail/binary>> ->
            {Data, Tail};
        _ -> 
            split_on_last_newline_1(Bin, Offset - 1)
    end;
split_on_last_newline_1(Bin, _) -> {Bin, <<>>}.
    
scan_chunk(Bin) -> scan_chunk_1(Bin, 0, dict:new()).  
scan_chunk_1(Bin, Offset, Dict) when Offset =< size(Bin) - 34 ->
    case Bin of
        %<<_:Offset/binary,"GET /ongoing/When/",_,_,_,$x,$/,Y1,Y2,Y3,Y4,$/,M1,M2,$/,D1,D2,$/,Rest/binary>> ->            
        <<_:Offset/binary,"GET /ongoing/When/",_:3/binary,$x,$/,Y:4/binary,$/,M:2/binary,$/,D:2/binary,$/,Rest/binary>> -> 
            case match_until_space_newline(Rest, 0) of
                {Rest1, <<>>} -> 
                    scan_chunk_1(Rest1, 0, Dict);
                {Rest1, Word} -> 
                    Key = <<Y/binary,$/,M/binary,$/,D/binary,$/, Word/binary>>,
                    scan_chunk_1(Rest1, 0, dict:update_counter(Key, 1, Dict))
            end;
        _ -> scan_chunk_1(Bin, Offset + 1, Dict)
    end;
scan_chunk_1(_, _, Dict) -> Dict.

match_until_space_newline(Bin, Offset) when Offset < size(Bin) ->
    case Bin of
        <<Word:Offset/binary,$ ,Rest/binary>> ->
            {Rest, Word};
        <<_:Offset/binary,$.,Rest/binary>> ->
            {Rest, <<>>};
        <<_:Offset/binary,10,Rest/binary>> ->
            {Rest, <<>>};
        _ ->
            match_until_space_newline(Bin, Offset + 1)
    end;
match_until_space_newline(_, _) -> {<<>>, <<>>}.



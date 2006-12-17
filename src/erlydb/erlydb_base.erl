%% @author Yariv Sadan <yarivvv@gmail.com> [http://yarivsblog.com]
%% @copyright Yariv Sadan 2006
%% @doc erlydb_base is the base module that all modules that ErlyDB generates
%% extend.
%% Generated modules inherit many of erlydb_base's exported functions
%% directly, but some of the functions in erlydb_base undergo additional
%% changes before they attain their final form in the generated module.
%% In addition, some functions in erlydb_base aren't used directly,
%% but only act as templates used to generate one or more other functions
%% in the new module.
%%
%% You can provide your own implementations for some of erlydb_base's functions
%% in your data access modules in order to override the default code generation
%% behavior. This is useful for telling ErlyDB about relations (one-to-many
%% and many-to-many) and which database tables and fields are 
%% used for different modules. For additional information, read
%% the function documentation below.

-module(erlydb_base).
-author("Yariv Sadan (yarivvv@gmail.com, http://yarivsblog.com)").

%% helps debugging
-define(L(Rec), io:format("LOG ~w ~p\n", [?LINE, Rec])).
-define(S(Rec), io:format("LOG ~w ~s\n", [?LINE, Rec])).

-export(
   [
    %% functions that the user can override give ErlyDB
    %% additional information about model relations 
    %% and how to map modules to database tables
    relations/0,
    fields/0,
    table/0,
    type_field/0,

    %% functions for getting information about a record
    is_new/1,

    %% functions for converting a record to an iolist
    to_iolist/2,
    to_iolist/3,
    field_to_iolist/1,
    field_to_iolist/2,

    %% functions for creating a record and setting its fields
    new/1,
    new_with/2,
    new_with/3,
    new_from_strings/2,
    set_fields/3,
    set_fields/4,
    set_fields_from_strs/3,
    field_from_string/2,

    %% CRUD functions
    save/1,
    delete/1,
    delete_where/2,
    delete_id/2,
    delete_all/1,
    transaction/2,

    %% hooks
    before_save/1,
    after_save/1,
    before_delete/1,
    after_delete/1,
    after_fetch/1,

    %% SELECT functions
    find/3,
    find_id/2,
    find_first/3,
    find_max/4,
    find_range/5,
    count/1,

    %% private exports

    %% one-to-many functions
    find_related_one_to_many/2,
    set_related_one_to_many/2,

    %% many-to-one functions
    find_related_many_to_one/4,
    aggregate_related_many_to_one/6,

    %% many-to-many functions
    add_related_many_to_many/3,
    remove_related_many_to_many/3,
    find_related_many_to_many/5,
    aggregate_related_many_to_many/7,
    
    %% variations on one-to-many and many-to-many find functions
    find_related_many_first/4,
    find_related_many_max/5,
    find_related_many_range/6,
    aggregate_related_many/6,

    %% functions for getting information about the module's table and database
    %% fields
    db_table/1,
    db_fields/1,
    db_field_names/1,
    db_field_names_str/1,
    db_field_names_bin/1,
    db_num_fields/1,
    db_field/2,

    %% internal functions
    field_names_for_query/1,
    field_names_for_query/2,
    get/2,
    set/3,
    get_module/1,
    driver/1,
    do_save/1,
    do_delete/1,
    aggregate/5    
   ]).

%% @doc Return the list of relations of the module. By overriding the function,
%%   you can tell ErlyDB what relations the module has. Possible relations
%%   are {one_to_many, [atom()]} and {many_to_many, [atom()]}. This function
%%   returns a list of such relations.
%%
%% @spec relations() -> [{one_to_many, [atom()]} | {many_to_many, [atom()]}]
relations() ->
    [].

%% @doc Return the list of fields that ErlyDB should use for the module.
%% You can override this function to specify which
%% database fields from the table besides the id field should be exposed
%% to records from the module.
%% The '*' atom indicates all fields, which is the default setting.
%%
%% Note: You are free to call the fields() function from other modules
%% to create arbitrary type relations.
%% For example, in a module called 'painting', you could have the function
%%
%%   fields() -> creation:fields() ++ [material, canvas, style]
%%
%% @spec fields() -> '*' | [atom()]
fields() ->
    '*'.


%% @doc Return the name of the table that holds the records for this module.
%%   By default, the table name is identical to the Module's name, but you
%%   can override this to use a different table name.
%%
%% @spec table() -> atom()
table() ->
    default.

%% @doc Return the column that identifies the types of the records in a table.
%%   This is useful when storing records from multiple modules in a single
%%   table, where each module uses a different subset of fields.
%%   If you override this function, in most cases you should also override
%%   fields/0.
%%
%% @spec type_field() -> atom()
type_field() ->
    undefined.

%% @doc Check if the record has been saved in the database.
%%
%% @spec is_new(Rec::tuple()) -> bool()
is_new(Rec) ->
    element(2, Rec).

%% @doc Return an iolist representing the record or list of records.
%%   This iolist is a
%%   concatenation of the values of the record's fields as returned from
%%   the db_fields/0 function.
%%   You can override the way the values are converted to strings/binaries
%%   by passing your own conversion Fun. This Fun can return 'default' to
%%   render using field_to_iolist/2.
%%
to_iolist(Module, Recs) ->
    to_iolist(Module, Recs, fun field_to_iolist/2).

%% @type to_iolist_function() = (ErlyDbField::erlydb_field(), Val::term()) ->
%%   binary() | string()
%% @spec to_iolist(Module::atom(), Rec::tuple() | [Rec::tuple()],
%%   ToIolistFun::to_iolist_function()) -> iolist()
to_iolist(Module, Recs, ToIolistFun) when is_list(Recs) ->
    [to_iolist1(Module, Rec, ToIolistFun) || Rec <- Recs];
to_iolist(Module, Recs, ToIolistFun) ->
    to_iolist1(Module, Recs, ToIolistFun).

to_iolist1(Module, Rec, ToIolistFun) ->
    Fields = lists:reverse(Module:db_fields()),
    IsDefaultFun = ToIolistFun == fun field_to_iolist/2,
    WrapperFun = 
	if IsDefaultFun -> ToIolistFun;
	   true ->
		fun(Val, Field) ->
			case ToIolistFun(Val, Field) of
			    default ->
				field_to_iolist(Val, Field);
			    Other ->
				Other
			end
		end
	end,
    lists:foldl(
      fun(Field, Acc) ->
	      FieldName = erlydb_field:name(Field),
	      Val = Module:FieldName(Rec),
	      [WrapperFun(Val, Field) | Acc]
      end, [], Fields).

%% A helper function for easy conversion of field values to iolists.
field_to_iolist(Val) ->
    field_to_iolist(Val, undefined).

field_to_iolist(Val, _Field) ->
    case Val of
	Bin when is_binary(Bin) -> Val;
	List when is_list(List) -> Val;
	Int when is_integer(Int) -> integer_to_list(Val);
	Float when is_float(Float) -> float_to_list(Val);
	{datetime, {{Year,Month,Day},{Hour,Minute,Second}}} ->
	    io_lib:format("~b/~b/~b ~b:~b:~b",
			  [Month, Day, Year, Hour, Minute, Second]);
	{date, {Year, Month, Day}} ->
	    io_lib:format("~b/~b/~b",
			  [Month, Day, Year]);
	{time, {Hour, Minute, Second}}  ->
	    io_lib:format("~b:~b:~b", [Hour, Minute, Second]);
	undefined -> [];
	_Other ->
	    io_lib:format("~p", [Val])
    end.


%% @doc Create a new record from this module with all fields set to
%%  'undefined'.
%%
%% @spec new(Module::atom()) -> tuple()
new(Module) ->
    Rec = erlang:make_tuple(Module:db_num_fields() + 2, undefined),
    Rec1 = set_is_new(Rec, true),
    set_module(Rec1, Module).

%% @doc Create a new record from this module with some fields assigned from
%%   Fields. Read the documentation for set_fields for more info.
%%
%% @spec new_with(Module::atom(), Fields::proplist()) -> tuple() | exit(Err)
new_with(Module, Fields) ->
    Module:set_fields(Module:new(), Fields).

%% @doc Create a new record for this module, using the ConvertValFun function
%%  to convert the values of the fields before setting them.
%%
%% @spec new_with(Module::atom(), Fields::proplist(),
%%   ToFieldFun::(erlydb_field(), Val) -> NewVal) -> tuple() | exit(Err)
new_with(Module, Fields, ToFieldFun) ->
    Module:set_fields(Module:new(), Fields, ToFieldFun).

%% @doc Create a new record for this module from a property list mapping
%%  field names to strings representing field values. The strings are converted
%%  to properly typed values using the field_from_string/2 function.
%%
%% @spec new_from_strings(Module::atom(),
%%  Fields::[{atom() | list(), list()}]) -> tuple() | exit(Err)
new_from_strings(Module, Fields) ->
    Module:set_fields(Module:new(), Fields, fun field_from_string/2).

%% @doc Set the record's fields using values from a property list.
%%
%% e.g. Language1 = language:set_fields(Language, [{name,"Erlang"},
%%                     {creation_year, 1981}])
%%
%% The property list can have keys that are either strings or atoms.
%% If the field name doesn't match an existing field for this record,
%% this function crashes.
%%
%% @spec set_fields(Module::atom(), Record::tuple(), Fields::proplist()) ->
%%   tuple()
set_fields(Module, Record, Fields) ->
    lists:foldl(
      fun({FieldName, Val}, Rec) ->
	      FieldName1 = get_field_name(Module, FieldName),
	      Module:FieldName1(Rec, Val)
      end, Record, Fields).

get_field_name(_Module, FieldName) when is_atom(FieldName) -> FieldName;
get_field_name(Module, FieldName) ->
    ErlyDbField = Module:db_field(FieldName),
    erlydb_field:name(ErlyDbField).

%% @doc Set the record's fields using values from a property list by first
%%  converting the values using the ToFieldFun.
%%
%% @type to_field_fun() = (erlydb_field(), Val::term()) -> NewVal::term()
%% @spec set_fields(Module::atom(), Record::tuple(), Fields::proplist(),
%%   ToFieldFun::to_field_fun()) -> tuple() | exit(Err)
set_fields(Module, Record, Fields, ToFieldFun) ->
    lists:foldl(
      fun({FieldName, Val}, Rec) ->
	      ErlyDbField = Module:db_field(FieldName),
	      FieldName1 = erlydb_field:name(ErlyDbField),
	      Module:FieldName1(Rec, ToFieldFun(ErlyDbField, Val))
      end, Record, Fields).


%% @doc Set the record's fields using values from a property list by first
%%  decoding their values from strings.
%%
%% @spec set_fields_from_strs(Module::atom(), Record::tuple(),
%%   Fields::proplist()) -> tuple() | exit(Err)
set_fields_from_strs(Module, Record, Fields) ->
    set_fields(Module, Record, Fields, fun field_from_string/2).

%% @doc A helper function for converting Strings to their corresponding
%%   Erlang types.
%%
%% @spec field_from_string(ErlyDbField::erlydb_field(), Str::list()) -> term()
field_from_string(ErlyDbField, undefined) ->
    case erlydb_field:null(ErlyDbField) of
	true -> undefined;
	false ->
	    exit({null_value,
		  erlydb_field:name(ErlyDbField)})
    end;
    
field_from_string(ErlyDbField, Str) ->
    if Str == undefined ->
	    case erlydb_field:null(ErlyDbField) of
		true -> undefined;
		false ->
		    exit({null_value,
			  erlydb_field:name(ErlyDbField)})
	    end;
       true ->
	    case erlydb_field:erl_type(ErlyDbField) of
		%% If the value started as a string, we keep it
		%% as a string and let the database driver convert it
		%% to binary before sending it to the socket.
		%% Note: this may change in a future version.
		binary -> Str; 
		integer -> fread_val("~d", Str);
		float ->
		    case catch fread_val("~f", Str) of
			{'EXIT', _} -> fread_val("~d", Str);
			Val -> Val
		    end;
		datetime ->
		    [Year, Month, Day, Hour, Minute, Second] =
			fread_vals("~d/~d/~d ~d:~d:~d", Str),
		    {datetime, {make_date(Year, Month, Day),
				make_time(Hour, Minute, Second)}};
		date -> 
		    [Month, Day, Year] = fread_vals("~d/~d/~d", Str),
		    {date, make_date(Year, Month, Day)};
		time ->
		    [Hour, Minute, Second] = fread_vals("~d:~d:~d", Str),
		    {time, make_time(Hour, Minute, Second)}
	    end
    end.

%% @doc Save an object by executing a INSERT or UPDATE query.
%%   By default, this function returns a modified tuple representing
%%   the record or throws an exception if an error occurs.
%%   The return value can be overridden by implementing the after_save
%%   hook.
%%
%% @spec save(Rec::tuple()) -> tuple() | exit(Err)
save(Rec) ->
    hook(Rec, do_save, before_save, after_save).

%% @doc Delete the record from the database. By default, this function
%%   returns 'ok' or crashes if the deletion succeeds.
%%   The return value can be overridden by implementing the after_delete
%%   hook.
%%
%% @spec delete(Rec::tuple()) -> ok | exit(Err)
delete(Rec) ->
    if_saved(Rec,
	     fun() ->
		     hook(Rec, do_delete, before_delete, after_delete)
	     end).

%% @doc Delete the record with the given id. Returns the number of
%%   records actually deleted.
%%
%% @spec delete_id(Module::atom(), Id::integer()) -> integer()
delete_id(Module, Id) ->
    delete_where(Module, {id,'=',Id}).

%% @doc Delete all records matching the Where expressions.
%%
%% @spec delete_where(Module::atom(), Where::where_expr()) ->
%% NumDeleted::integer() | exit(Err)
delete_where(Module, Where) ->
    {DriverMod, Options} = Module:driver(),
    case DriverMod:transaction(
	   fun() ->
		   DriverMod:update(
		     {esql, {delete, {from, db_table(Module)},
			     make_where_expr(Module, Where)}},
		     Options)
	   end, Options)
	of
	{atomic, {ok, NumDeleted}} ->
	    NumDeleted;
	{aborted, Err} ->
	    exit(Err)
    end.

%% @doc Delete all records from the module.
%%
%% @spec delete_all(Module::atom()) -> NumDeleted::integer() | exit(Err)
delete_all(Module) ->
    delete_where(Module, undefined).

%% @doc Execute a transaction using the module's driver settings.
%%
%% @spec transaction(Module::atom(), Fun::function()) ->
%%   {atomic, Result::term()} | {aborted, Details}
transaction(Module, Fun) ->
    {DriverMod, Options} = Module:driver(),
    DriverMod:transaction(Fun, Options).


%% hooks

%% @doc A hook that gets called before a record is saved. This function
%%   be overridden in the target module. To abort the operation, this hook
%%   can throw an exception or crash.
%%
%% @spec before_save(Rec::tuple()) -> tuple() 
before_save(Rec) ->
    Rec.

%% @doc A hook that gets called after a record is saved. This function
%%   be overridden by the user.
%%
%% @spec after_save(Rec::tuple()) -> tuple()
after_save(Rec) ->
    Rec.

%% @doc A hook that gets called before a record is deleted. This function
%%   be overridden in the target module. To abort the operation, this hook
%%   can throw an exception or crash.
%%
%% @spec before_delete(Rec::tuple()) -> tuple()
before_delete(Rec) ->
    Rec.

%% @doc A hook that gets called after a record is deleted. This function be
%%   be overridden in the target module.
%%
%% @spec after_delete(Rec::tuple()) -> ok
after_delete(_Rec) ->
    ok.


%% @doc A hook that gets called after a record is fetched from the database.
%%   This function be overridden in the target module.
%%
%% @spec after_fetch(Rec::tuple()) -> tuple()
after_fetch(Rec) ->
    Rec.


%% find functions

%% @doc Find records for the module. The Where and Extras clauses are,
%%  by default, ErlSQL expressions. Example Where expressions are
%%    {name,'=',"Joe"}
%%  and
%%    {{age,'>',26},'and',{country,like,"Australia"}}
%%  
%%  Example Extras expressions are
%%    {limit, 7}
%%  and
%%    [{limit, 4,5}, {order_by, [name, {age, desc}]}]
%%
%%  The main benefits of using ErlSQL are
%%  - It protects against SQL injection attacks by quoting all string
%%    values.
%%  - It simplifies embedding runtime variables in SQL expressions
%%    by stringifying values such as numbers, atoms, dates and times.
%%  - It's more efficient than string concatenation because it generates
%%    iolists of binaries, which generally consume less memory than
%%    strings.
%%
%% For more information, visit http://code.google.com/p/erlsql.
%%
%% Some drivers (e.g. the MySQL driver), let you use string and binary
%% expressions directly when you set the 'unsafe_sql' option to 'true'
%% when calling erlydb:code_gen. This usage is discouraged because it
%% makes you vulnerable to SQL injection attacks if you don't properly
%% encode all your strings.
%%
%% The code generation process automatically creates a few variations on
%% this function:
%%
%%   find(Module)
%%   find(Module, Where)
%%   find_with(Module, Extras)
%%
%% (This applies to all find_X and aggregate_X functions in erlydb_base.erl)
%%
%% @spec find(Module::atom(), Where::where_expr(), Extras::extras_expr()) ->
%%   [tuple()] | exit(Err)
find(Module, Where, Extras) ->
    do_find(Module, field_names_for_query(Module, true), Where, Extras).

%% @doc Find the first record for the module according to the Where and
%%   Extras expressions.
%%
%% @spec find_first(Modue::atom(), Where::where_expr(),
%%  Extras::extras_expr()) -> tuple() | exit(Err)
find_first(Module, Where, Extras) ->
    as_single_val(find_max(Module, 1, Where, Extras)).

%% @doc Find up to Max records from the module according
%%   to the Where and Extras expressions.
%%
%% @spec find_max(Module::atom(), Max::integer(), Where::where_expr(),
%%   Extras::extras_expr()) -> [tuple()] | exit(Err)
find_max(Module, Max, Where, Extras) ->
    find(Module, Where, append_extras({limit, Max}, Extras)).

%% @doc Find up to Max records, starting from offset First,
%%   according to the Where and Extras expressions.
%%
%% @spec find_range(Module::atom(), First::integer(), Max::integer(),
%%   Where::where_expr(), Extras::extras_expr()) -> [tuple()] | exit(Err)
find_range(Module, First, Max, Where, Extras) ->
    find(Module, Where, append_extras({limit, First, Max}, Extras)).

%% @doc Find the record with the given Id.
%%
%% @spec find_id(Module::atom(), Id::term()) -> Rec | exit(Err)
find_id(Module, Id) ->
    as_single_val(find(Module, {id,'=',Id}, undefined)).


%% @doc Call an aggregate function such as 'count', 'sum', 'min', 'max',
%%  or 'avg' on the given field of records from the module matching the
%%  Where and Extras expressions.
%%  In code generation time, this function is used to create
%%  aggregate functions for a module, e.g. person:avg(age) and their
%%  variations as in the find() function.
%%
%% @spec aggregate(Module::atom(), AggFunc::atom(), Field::atom(),
%%  Where::where_expr(), Extras::extras_expr()) -> number() | exit(Err)
aggregate(Module, AggFunc, Field, Where, Extras) ->
    do_find(Module, {call, AggFunc, Field}, Where, Extras,
	    false).

%% @doc A shortcut for counting all the records for a module. This allows
%%    calling person:count() instead of person:count('*').
%%
%% @spec count(Module::atom()) -> integer() | exit(Err)
count(Module) ->
    aggregate(Module, 'count', '*', undefined, undefined).


%% one-to-many functions

set_related_one_to_many(Rec, Other) ->
    if_saved(Other,
	     fun() ->
		     FuncName = get_id_field(Other),
		     Module = get_module(Rec),
		     Module:FuncName(Rec, get_id(Other))
	     end).

find_related_one_to_many(OtherModule, Rec) ->
    FuncName = list_to_atom(atom_to_list(OtherModule) ++ "_id"),
    ModName = get_module(Rec),
    as_single_val(OtherModule:find({id,'=', ModName:FuncName(Rec)})).


%% many-to-one functions

find_related_many_to_one(OtherModule, Rec, Where,
			Extras) ->
    if_saved(Rec,
      fun() ->
	      OtherModule:find(
		make_id_expr(Rec, Where), Extras)
      end).

aggregate_related_many_to_one(OtherModule, AggFunc, Rec, Field, Where,
			      Extras) ->
    if_saved(Rec,
	     fun() ->
		     OtherModule:AggFunc(Field,
					 make_id_expr(Rec, Where), Extras)
	     end).

%% many-to-many functions

add_related_many_to_many(JoinTable, Rec, OtherRec) ->
    if_saved(
      [Rec,OtherRec],
      fun() ->
	      {DriverMod, Options} = get_driver(Rec),
	      Query = {esql, make_add_related_many_to_many_query(
			       JoinTable, Rec, OtherRec)},
	      Res = DriverMod:update(Query, Options),
	      as_single_update(Res)
      end).

make_add_related_many_to_many_query(JoinTable, Rec, OtherRec) ->
    {insert, JoinTable,
     [{get_id_field(Rec), get_id(Rec)},
      {get_id_field(OtherRec), get_id(OtherRec)}]}.

remove_related_many_to_many(JoinTable, Rec, OtherRec) ->
    if_saved(
      [Rec, OtherRec],
      fun() ->
	      {DriverMod, Options} = get_driver(Rec),
	      Query = make_remove_related_many_to_many_query(
			JoinTable, Rec, OtherRec),
	      as_single_update(DriverMod:update({esql, Query}, Options))
      end).

make_remove_related_many_to_many_query(JoinTable, Rec, OtherRec) ->
    {delete, JoinTable, {{get_id_field(Rec),'=',get_id(Rec)},
			 'and',
			 {get_id_field(OtherRec),'=',get_id(OtherRec)}}}.


find_related_many_to_many(OtherModule, JoinTable, Rec, Where, Extras) ->
    Fields = [{db_table(OtherModule), Field} ||
		 Field <- OtherModule:field_names_for_query()],
    find_related_many_to_many2(OtherModule, JoinTable, Rec, Fields,
			       Where, Extras, true).

find_related_many_to_many2(OtherModule, JoinTable, Rec, Fields,
			   Where, Extras, AsModule) ->
    if_saved(Rec,
	     fun() ->
		     Query = {esql, make_find_related_many_to_many_query(
				      OtherModule, JoinTable, Rec, Fields,
				      Where, Extras)},
		     select(OtherModule, Query, AsModule)
	     end).

make_find_related_many_to_many_query(OtherModule, JoinTable, Rec, Fields,
				     Where, Extras) ->
    Cond = {
      {{db_table(OtherModule), id},'=',
       {JoinTable, get_id_field(OtherModule)}},
      'and',
      {{JoinTable, get_id_field(Rec)}, '=', get_id(Rec)}
     },

    {select, Fields,
     {from, [db_table(OtherModule), JoinTable]},
     make_where_expr(OtherModule, Cond, Where),
     Extras}.

aggregate_related_many_to_many(OtherModule, JoinTable, AggFunc, Rec, Field,
			       Where, Extras) ->
    find_related_many_to_many2(
      OtherModule, JoinTable, Rec,
      {call, AggFunc, Field}, Where, Extras, false).



%% generic find functions for both many-to-one and many-to-many relations

find_related_many(Func, Rec, Where, Extras) ->
    Mod = get_module(Rec),
    Mod:Func(Rec, Where, Extras).

find_related_many_first(Func, Rec, Where, Extras) ->
    find_related_many_max(Func, Rec, 1, Where, Extras).

find_related_many_max(Func, Rec, Num, Where, Extras) ->
    find_related_many(Func, Rec, Where, append_extras({limit, Num},Extras)).

find_related_many_range(Func, Rec, First, Last, Where, Extras) ->
    find_related_many(Func, Rec, Where,
		      append_extras({limit, First, Last}, Extras)).

aggregate_related_many(Func, AggFunc, Rec, Field, Where, Extras) ->
    Module = get_module(Rec),
    Module:Func(AggFunc, Rec, Field, Where, Extras).




%% internal functions

do_save(Rec) ->
    {DriverMod, Options} = get_driver(Rec),
    Res =
	case make_save_statement(Rec) of
	    {insert, Stmt} ->
		DriverMod:transaction(
		  fun() ->
			  case DriverMod:update({esql, Stmt}, Options) of
			      {ok, 1} ->
				  case DriverMod:get_last_insert_id(Options) of
				      {ok, Id} ->
					  Rec1 = set_is_new(Rec, false),
					  set_id(Rec1, Id);
				      Err ->
					  Err
				  end;	    
			      Err ->
				  Err
			  end
		  end, Options);
	    {update, Stmt} ->
		DriverMod:transaction(
		  fun() ->
			  case DriverMod:update({esql, Stmt}, Options) of
			      {ok, Num} when Num == 0; Num == 1 ->
				  Rec;
			      Other ->
				  Other
			  end
		  end, Options)
	end,
    case Res of
	{atomic, NewRec} -> NewRec;
	{aborted, Err} -> exit(Err)
    end.

make_save_statement(Rec) ->
    Module = get_module(Rec),
    [_IdField | Fields] = field_names_for_query(Module),
    case is_new(Rec) of
	false ->
	    [_Module, _IsNew1, Id | Vals] = tuple_to_list(Rec),
	    {update, {update, get_table(Rec), lists:zip(Fields, Vals),
		      {where, {id,'=',Id}}}};
	true ->
	    [_Module, _IsNew1, _Pk | Vals] = tuple_to_list(Rec),
	    {Fields1, Vals1} =
		case Module:type_field() of
		    undefined -> {Fields, Vals};
		    TypeField -> {[TypeField|Fields], [Module|Vals]}
		end,
	    {insert, {insert, get_table(Rec), Fields1, [Vals1]}}
    end.


do_delete(Rec) ->
    if_saved(
      Rec,
      fun() ->
	      {DriverMod, Options} = get_driver(Rec),
	      Stmt = make_delete_stmt(Rec),
	      Res = DriverMod:transaction(
		      fun() ->
			      case DriverMod:update(Stmt, Options) of
				  {ok, 1} ->
				      Rec;
				  {ok, 0} ->
				      {error, {delete_failed, Rec}};
				  {ok, Num} ->
				      {error,
				       {too_many_rows_deleted, Num,
					Rec}};
				  Err ->
				      Err
			      end
		      end, Options),
	      case Res of
		  {atomic, Result} -> Result;
		  {aborted, Err} -> exit(Err)
	      end
      end).

make_delete_stmt(Rec) ->
    {esql, {delete, get_table(Rec),
	    {where, {id,'=',get_id(Rec)}}}}.

do_find(Module, Fields, Where, Extras) ->
    do_find(Module, Fields, Where, Extras, true).

do_find(Module, Fields, Where, Extras, AsModule) ->
    select(Module, make_find_query(Module, Fields, Where, Extras), AsModule).
	
make_find_query(Module, Fields, Where, Extras) ->
    {esql,
     {select, Fields, {from, db_table(Module)},
      make_where_expr(Module, Where),
      Extras}}.
    

get_id_field(Rec) when is_tuple(Rec) ->
    get_id_field(get_module(Rec));
get_id_field(Module) ->
    list_to_atom(atom_to_list(Module) ++ "_id").

make_id_expr(Rec, Where) ->
    and_expr({get_id_field(Rec),'=',get_id(Rec)}, Where).

append_extras(Clause, Extras) ->
    case Extras of
	undefined ->
	    Clause;
	L when is_list(L) ->
	    Extras ++ Clause;
	OtherClause ->
	    [OtherClause, Clause]
    end.

select(Module, Query, true) ->
    {DriverMod, Options} = Module:driver(),
    Res = DriverMod:select_as(Module, Query, Options),
    case Res of
	{ok, Rows} ->
	    F = fun(Rec) -> Module:after_fetch(Rec) end,
	    lists:map(F, Rows);
	Err ->
	    exit(Err)
    end;
select(Module, Query, false) ->
    {DriverMod, Options} = Module:driver(),
    as_single_val(DriverMod:select(Query, Options), true).
    

%% Enables the before_X and after_X hooks.
hook(Rec, Func, BeforeFunc, AfterFunc) ->
    Module = get_module(Rec),
    Rec1 = Module:BeforeFunc(Rec),
    Rec2 = Module:Func(Rec1),
    Module:AfterFunc(Rec2).


%% functions for getting information about the database table and fields
%% for a module

%% @doc Get the table name for the module.
%%
%% @spec db_table(Module::atom()) -> atom()
db_table(Module) ->
    case Module:table() of
	default ->
	    Module;
	Other ->
	    Other
    end.

%% @doc Get the number of fields for the module.
%%
%% @spec db_num_fields(NumFields::integer()) -> integer()
db_num_fields(NumFields) ->
    NumFields.

%% @doc Get a list of erlydb_field records representing the database fields
%%  for the module.
%%
%% @spec db_fields(Fields::[erlydb_field()]) -> [erlydb_field()]
db_fields(Fields) ->
    Fields.

%% @doc Get the module's database fields' names as atoms.
%%
%% @spec db_field_names(FileNames::[atom()]) -> [atom()]
db_field_names(FieldNames) ->
    FieldNames.

%% @doc Get the module's database fields' names as strings.
%%
%% @spec db_field_names_str(FieldNameStrs::[string()]) -> [string()]
db_field_names_str(FieldNameStrs) ->
    FieldNameStrs.

%% @doc Get the module's database fields' names as binaries.
%%
%% @spec db_field_names_bin(FieldNamesBin::[binary()]) -> [binary()]
db_field_names_bin(FieldNamesBin) ->
    FieldNamesBin.

%% @doc Get the erlydb_field record matching the the given name.
%%   If the field isn't found, this function crashes.
%%
%% @spec db_field(Module::atom(), FieldName::string() | atom()) ->
%%   erlydb_field()
db_field(Module, FieldName) ->
    Pred = if is_list(FieldName) ->
		    fun(Field) ->
			    erlydb_field:name_str(Field) == FieldName
		    end;
	     true ->
		    fun(Field) ->
			    erlydb_field:name(Field) == FieldName
		    end
	  end,

    case find_val(Pred, Module:db_fields()) of
	none -> exit({no_such_field, {Module, FieldName}});
	{value, Field} -> Field
    end.

find_val(_Pred, []) -> none;
find_val(Pred, [First | Rest]) ->
    case Pred(First) of
	true -> {value, First};
	false -> find_val(Pred, Rest)
    end.
    

%% internal functions

get_driver(Rec) ->
    Module = get_module(Rec),
    Module:driver().


field_names_for_query(Module) ->
    field_names_for_query(Module, false).
field_names_for_query(Module, UseStar) ->
    case Module:fields() of
	'*' ->
	    case Module:type_field() of
		undefined ->
		    if UseStar -> '*';
		       true -> Module:db_field_names()
		    end;
		_TypeCol ->
		    Module:db_field_names()
	    end;
	Fields ->
	    [id | Fields]
    end.


%% A metafunction for generating getters, e.g. person:name(Person).
get(Idx, Tuple) ->
    element(Idx, Tuple).

%% A metafunction for generating setters, e.g. person:name(Person, "Bob")
set(Idx, Tuple, Val) ->
    setelement(Idx, Tuple, Val).


driver(Driver) ->
    Driver.

if_saved(Rec, Fun) when not is_list(Rec) ->
    if_saved([Rec], Fun);
if_saved(Recs, Fun) ->
    case catch lists:foreach(
	    fun(Rec) ->
		    case is_new(Rec) of
			true ->
			    throw({error, {no_such_record, Rec}});
			false ->
			    ok
		    end
	    end, Recs)
	of
	ok ->
	    Fun();
	Err ->
	    exit(Err)
    end.


get_module(Rec) ->
    element(1, Rec).

set_module(Rec, Module) ->
    setelement(1, Rec, Module).

get_table(Rec) ->
    Module = get_module(Rec),
    db_table(Module).

get_id(Rec) ->
    element(3, Rec).

set_id(Rec, Id) ->
    setelement(3, Rec, Id).

set_is_new(Rec, Val) ->
    setelement(2, Rec, Val).


make_where_expr(Module, Expr) ->
    make_where_expr(Module, Expr, undefined).
make_where_expr(Module, {where, Expr1}, Expr2) ->
    make_where_expr(Module, Expr1, Expr2);
make_where_expr(Module, Expr1, {where, Expr2}) ->
    make_where_expr(Module, Expr1, Expr2);
make_where_expr(Module, Expr1, Expr2) ->
    case Module:type_field() of
	undefined ->
	    case and_expr(Expr1, Expr2) of
		undefined ->
		    undefined;
		Other ->
		    {where, Other}
	    end;
	FieldName ->
	    Expr3 = and_expr(Expr1, Expr2),
	    {where, and_expr({{db_table(Module),FieldName}, '=',
			      atom_to_list(Module)},
				 Expr3)}
    end.

and_expr({where, Expr1}, Expr2) -> and_expr(Expr1, Expr2);
and_expr(Expr1, {where, Expr2}) -> and_expr(Expr1, Expr2);
and_expr(undefined, Expr2) -> Expr2;
and_expr(Expr1, undefined) -> Expr1;
and_expr(Expr1, Expr2) -> {Expr1, 'and', Expr2}.

as_single_update({ok, 1}) -> ok;
as_single_update({ok, Num}) -> exit({error, {unexpected_num_updates, Num}});
as_single_update({error, _} = Err) -> exit(Err).

as_single_val(Res) -> as_single_val(Res, false).

as_single_val({ok, [{Val}]}, true) -> Val;
as_single_val([], _) -> undefined;
as_single_val([Val], false) -> Val;
as_single_val({error, _} = Err, _) -> exit(Err);
as_single_val(Res, _) -> exit({error, {too_many_results, Res}}).

fread_val(Format, Str) ->
    [Val] = fread_vals(Format, Str),
    Val.

fread_vals(Format, Str) ->
    case io_lib:fread(Format, Str) of
	{ok, Vals, []} -> Vals;
	{ok, _, Rest} -> exit({invalid_input, Rest});
	{more, _, _, _} -> exit({missing_values, Str});
	_Err -> exit({parse_error, Format, Str})
    end.

make_date(Year, Month, Day) ->
    check_limits(Month, month, 1, 12),
    check_limits(Day, day, 1, 31),
    check_limits(Year, year, 1, 9999),
    {Year, Month, Day}.

make_time(Hour, Minute, Second) ->
    check_limits(Hour, hour, 0, 23),
    check_limits(Minute, minute, 0, 59),
    check_limits(Second, second, 0, 59),
    {Hour, Minute, Second}.

check_limits(Val, Name, Min, Max) ->
    if Val > Max orelse Val < Min ->
	    exit({invalid_value, Name, Val});
       true -> Val
    end.

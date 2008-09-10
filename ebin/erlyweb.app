{application, erlyweb,
    [{description, "ErlyWeb application"},
     {vsn, "1.7.1"},
     {modules,
		[ erlyweb_compile
		, erlyweb_controller
		, erlyweb
		, erlyweb_forms
		, erlyweb_util
		, yaws_arg
		, yaws_headers
        ]},
     {registered, []},
     {applications, [kernel,
                     stdlib,
                     compiler]},
     {env, []}]}.


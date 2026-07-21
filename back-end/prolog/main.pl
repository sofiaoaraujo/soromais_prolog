:- encoding(utf8).

weather(islamabad, summer, hot).
weather(karachi, summer, warm).
weather(islamabad, winter, cold).
weather(karachi, winter, warm).

:- initialization(main, main).

main :-
    weather(islamabad, summer, X),
    format("Clima em Islamabad no verão: ~w~n", [X]).

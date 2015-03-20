Log all TNotifyEvents (e.g. `OnChange`, `OnEnter`, `OnExit`) to the Delphi Event Log in the debugger window.
Useful when tracking down weird interactions between Delphi events.

### To use: ###
  1. Download the `EventInterceptor` Unit from [here](http://code.google.com/p/delphieventlogger/downloads/list) and add it to your project
  1. Add the `EventInterceptor` Unit to the Uses clause
  1. Add this line somewhere in your code for each form you want to track.

`AddEventInterceptors(MyForm);`

`MyForm` can be any TControl (e.g. a form, a control etc.)

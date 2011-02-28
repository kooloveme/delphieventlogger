unit EventInterceptor;

/// <summary> Log all TNotifyEvents (e.g. OnChange, OnEnter, OnExit) to the Delphi Event Log in the debug window.
/// All child controls are monitored as well.
/// Alternatively, provide your own code to execute on these events (e.g. write to a file)
/// To use:
/// * Add the EventInterceptor Unit to the Uses clause
/// * Add this line somewhere in your code for each form you want to track.
/// "AddEventInterceptors(MyForm);"
/// MyForm can be any TControl (e.g. a form, a control etc.)
///
/// To do something different on an event (e.g. write to standard out) provide a callback.
/// AddEventInterceptors(self,procedure (Sender: TObject; Control:TControl; EventName:string) begin
///        WriteLn(Control.Name+'.'+EventName); end);
///
/// Possible improvements:
/// Track other types of events besides TNotifyEvent e.g. Click Events.
/// </summary>
interface

uses Classes, Controls, Generics.Collections, Rtti;

type TInterceptEvent=reference to procedure(Sender: TObject; Control:TControl; EventName:string);

type TEventInterceptor=class(TComponent)
    private
        EventName:string;
        Control:TControl;
        originalEvent:TNotifyEvent;
        newEvent:TInterceptEvent;
        class procedure RecurseControls(Control: TControl; ExaminedControls: TList<TControl>; context:TRttiContext; InterceptEvent:TInterceptEvent);
    public
        procedure HandleEvent(Sender: TObject);
        constructor Create(Control:TControl; EventName:string; OriginalEvent:TNotifyEvent; InterceptEvent:TInterceptEvent);
  end;

/// <summary> Track events on a TControl and all it's child controls. By default, all events are logged to the Delphi
/// Event Log</summary>
/// <param> Control Log all events that occurr on this Control or any of its Children. Note that any Form is a TControl.</param>
/// <param> InterceptEvent Optional. Code to execute each time an event is intercepted</param>
procedure AddEventInterceptors(Control:TControl; InterceptEvent:TInterceptEvent=nil);

implementation

uses TypInfo, SysUtils, Windows;

constructor TEventInterceptor.Create(Control:TControl; EventName: string; OriginalEvent: TNotifyEvent; InterceptEvent:TInterceptEvent);
begin
    inherited Create(Control);
    self.Control:=Control;
    self.EventName:=EventName;
    self.originalEvent:=OriginalEvent;
    self.newEvent:=InterceptEvent;
end;

procedure TEventInterceptor.HandleEvent(Sender: TObject);
begin
    newEvent(Sender,Control,EventName);
    originalEvent(Sender);
end;

class procedure TEventInterceptor.RecurseControls(Control: TControl; ExaminedControls: TList<TControl>; context:TRttiContext; InterceptEvent:TInterceptEvent);
var
  theTypeInfo: TRttiInstanceType;
  theProperty: TRttiProperty;
  interceptor: TEventInterceptor;
  theEvent: TNotifyEvent;
  theValue: TValue;
  field: TRttiField;
  newControl: TControl;
  instanceType: TRTTIInstanceType;
begin
    ExaminedControls.add(Control);

    theTypeInfo:=context.GetType(Control.ClassInfo) as TRttiInstanceType;

    for theProperty in theTypeInfo.GetProperties do
    begin
        if (theProperty.PropertyType.ToString='TNotifyEvent') and theProperty.IsWritable then
        begin
            theValue:=theProperty.GetValue(Control);
            theEvent:=nil;
            if not theValue.IsEmpty then theEvent:=theValue.AsType<TNotifyEvent>();
            if Assigned(theEvent) then
            begin
                interceptor:=TEventInterceptor.Create(Control,theProperty.Name, theEvent, InterceptEvent );
                theProperty.SetValue(Control,TValue.From<TNotifyEvent>(interceptor.HandleEvent));
            end;
        end
    end;

    try
    for field in theTypeInfo.GetFields do
    begin
        if field.FieldType.TypeKind=tkClass then
        begin
            instanceType:=field.FieldType As TRttiInstanceType;
            if instanceType.MetaclassType.InheritsFrom(TControl) then
            begin
                newControl:=nil;
                theValue:=field.GetValue(Control);
                if not theValue.IsEmpty then newControl:=theValue.AsType<TControl>;
                if Assigned(newControl) then if not ExaminedControls.Contains(newControl) then
                    RecurseControls(newControl, ExaminedControls, context, InterceptEvent);
            end;
        end;
    end;
    except on E:EAccessViolation do
        // For some reason we can get an AccessViolation while looping through the fields. Seemed to happen
        // on ParentControl.
    end;
end;

procedure AddEventInterceptors(Control:TControl; InterceptEvent:TInterceptEvent=nil);
var
    examinedObjects: TList<TControl>;
begin
    examinedObjects:=TList<TControl>.Create;
    examinedObjects.add(Control);

    if Not Assigned(InterceptEvent) then InterceptEvent:=procedure(Sender: TObject; Control:TControl; EventName:string)
    begin
        OutputDebugString(PWideChar(Control.Name+'.'+EventName));
    end;

    TEventInterceptor.RecurseControls(Control, examinedObjects, TRttiContext.Create, InterceptEvent);
    examinedObjects.Free;
end;

end.

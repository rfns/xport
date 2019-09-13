Class XPort.Util.DynamicStatus [ Abstract ]
{

ClassMethod ToDynamicObject(status As %Status, Output error As %DynamicObject = "") As %Status
{
  set sc = $$$OK

  try {
    if $$$ISERR(status) {
      set exception = ##class(Frontier.Exception).CreateFromStatus(status)
      set error = ##class(Frontier.Exception).ToDynamicObject(exception)
      if $isobject(error) {
        if error.error '= "" set error = error.error        
        if error.errors '= "" set error = error.errors
      }
    }
  } catch err {
    set sc = err.AsStatus()
  }

  return sc
}

}


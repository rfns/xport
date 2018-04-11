Class XPort.API Extends Frontier.Router
{

Parameter HandleCorsRequest = "true";

Parameter UseSession As INTEGER = 1;

XData UrlMap [ XMLNamespace = "http://github.com/rfns/xport" ]
{
<Routes>
<Route Url="/ping" Method="GET" UseAuth="false" Call="Ping"/>
<Map Prefix="/:namespace/:project" Forward="XPort.API.Project"/>
</Routes>
}

ClassMethod OnSetup() As %Status
{
  
  // Disables path normalization and tries to resolve using the received path syntax.
  set ^||Port.Internals.Settings("remote") = 1  
  
  set %frontier.PropertyFormatter = ##class(Frontier.PropertyFormatter.SnakeCase).%New()   
  
  set basicStrategy = ##class(Frontier.Authentication.BasicStrategy).%New({
   "realm": "source",
   "validator": ($classname()_":ValidateCredentials"),
   "required": true
  })
  
  $$$QuitOnError(%frontier.AuthenticationManager.AddStrategy(basicStrategy))
  return $$$OK
}

ClassMethod ValidateCredentials(login As %String, password As %String, Output found As %Boolean = 1, Output httpStatus As %String, Output user As %DynamicObject) As %Status
{
    
  if $System.Security.CheckUserPermission(login, "%Development", "USE") {
    set found = $System.Security.Login(login, password)
  } else {
    set httpStatus = ..#HTTP403FORBIDDEN
    return $$$ERROR($$$RequiresRoleForConnection, "%Development")
  }  
  return $$$OK
}

ClassMethod Ping() As %Status
{
  do %frontier.Raw()
  return ""
}

}


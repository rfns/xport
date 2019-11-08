Class XPort.API Extends Frontier.Router
{

Parameter UseSession = 1;

Parameter APIVERSION = "0.13.0";

XData UrlMap [ XMLNamespace = "http://github.com/rfns/xport" ]
{
<Routes>
<Route Url="/ping" Method="HEAD" UseAuth="false" Call="Ping"/>
<Route Url="/info" Method="GET" UseAuth="false" Call="GetAPIInfo" />
<Map Prefix="/namespaces/:namespace/projects" Forward="XPort.API.Projects"/>
<Map Prefix="/namespaces/:namespace/documents" Forward="XPort.API.Documents"/>
</Routes>
}

ClassMethod OnSetup() As %Status
{
  #dim %frontier As Frontier.Context  

  // Disables path normalization and tries to resolve using the received path syntax.
  set ^||Port.Internals.Configuration("remote") = 1

  set %frontier.PropertyFormatter = ##class(Frontier.PropertyFormatter.SnakeCase).%New()

  set basicStrategy = ##class(Frontier.Authentication.BasicStrategy).%New({
   "realm": "source",
   "validator": ($classname()_":ValidateCredentials")
  })

  do %frontier.CORS.Default()
  $$$QuitOnError(%frontier.AuthenticationManager.AddStrategy(basicStrategy))

  return $$$OK
}

ClassMethod ValidateCredentials(login As %String, password As %String, Output found As %Boolean = 1, Output httpStatus As %String, Output user As %DynamicObject) As %Status
{
  set found = $System.Security.Login(login, password)
  if 'found {
    set httpStatus = ..#HTTP403FORBIDDEN
    return $$$ERROR($$$InvalidUsernameOrPassword)
  }

  if '$System.Security.CheckUserPermission(login, "%Development", "USE") {
    set httpStatus = ..#HTTP403FORBIDDEN
    return $$$ERROR($$$RequiresRoleForConnection, "%Development")
  }
  return $$$OK
}

ClassMethod Ping() As %String
{
  return ""
}

ClassMethod GetAPIInfo() As %DynamicObject
{
  set name = ##class(XPort.Installer).#NAME
  
  new $namespace
  set $namespace = "%SYS"
  
  do ##class(Security.Applications).Get(name, .d)
  
  return {
    "version": (..#APIVERSION),
    "application": (name),
    "namespace": (d("NameSpace")),
    "dispatcher": (d("DispatchClass"))
  }
}

}


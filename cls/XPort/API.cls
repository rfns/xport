Class XPort.API Extends Frontier.Router
{

XData UrlMap [ XMLNamespace = "http://github.com/rfns/xport" ]
{
<Routes>
<Route Url="/ping" Method="HEAD" UseAuth="false" Call="Ping"/>
<Route Url="/webapps" Method="GET" UseAuth="false" Call="ListLegacyWebApplications" />
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

ClassMethod ListLegacyWebApplications(namespace As %String)
{
}

}


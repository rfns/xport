Class XPort.API.Project Extends Frontier.Router
{

Parameter HandleCorsRequest = "true";

XData UrlMap [ XMLNamespace = "http://github.com/rfns/xport" ]
{
<Routes>
<Route Url="/" Method="POST" Call="CreateProject"/>
<Route Url="/xml" Method="GET" Call="GetProjectXML" />
<Map Prefix="/items" Forward="XPort.API.Project.Items"/>
</Routes>
}

ClassMethod GetProjectXML(namespace As %String, project As %Studio.Project) As %Stream.Object
{
  if '$isobject(project) return %frontier.ThrowException("A project with the name '"_%frontier.RouteParameters("project")_"' does not exist.")
  $$$ThrowOnError(project.ExportToStream("/nodisplay", 0,.errors,,"UTF8"))
  return project.Stream
}

}


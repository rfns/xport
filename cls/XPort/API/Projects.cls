Include xport

Class XPort.API.Projects Extends Frontier.Router
{

XData UrlMap [ XMLNamespace = "http://github.com/rfns/xport" ]
{
<Routes>
<Route Url="/" Method="GET" Call="ListProjects" />
<Route Url="/:project" Method="DELETE" Call="DeleteProject" />
<Route Url="/:project/create" Method="POST" Call="CreateProject"/>
<Route Url="/:project/xml" Method="GET" Call="GetProjectXML" />
<Route Url="/:project/compile" Method="POST" Call="CompileProject" />
<Map Prefix="/:project/items" Forward="XPort.API.Projects.Items"/>
</Routes>
}

ClassMethod GetProjectXML(namespace As %String, project As %String) As %Stream.Object
{
  return { "xml": (##class(XPort.Util.NamespaceCall).ExportProjectToXML(namespace, project)) }
}

ClassMethod ListProjects(namespace As %String) As %DynamicObject
{
  return ##class(XPort.Util.NamespaceCall).ListProjects(namespace)
}

ClassMethod DeleteProject(namespace As %String, project As %String) As %DynamicObject
{
  do ##class(XPort.Util.NamespaceCall).DeleteProject(namespace, project)

  return {
    "deleted": true
  }
}

ClassMethod CompileProject(namespace As %String, project As %String, options As %String = "cku", legacySourceControl As %Boolean = 0) As %DynamicObject
{
  set options = options_"/nodisplayerror"
  $$$CheckLegacySourceControl(legacySourceControl)

  set sc = ##class(Frontier.Shared.Utilities).CallAndCapture("XPort.Util.NamespaceCall", "CompileProject", .output, namespace, project, options)
  $$$ThrowOnError(##class(XPort.Util.DynamicStatus).ToDynamicObject(sc, .error))

  set log = []
  set errors = []

  if $isobject(error) {
    if 'error.%IsA("%DynamicArray") set errors = [(error)]
  }

  if $$$ISOK(sc) && $isobject(output) {
    while 'output.AtEnd {
      set line = output.ReadLine()
      if $extract(line, 1, 2) = ", " set line = $extract(line, 3, *)
      if line '= "" do log.%Push(line)
    }
  }

  return {
    "errors": (errors),
    "log": (log)
  }
}

}

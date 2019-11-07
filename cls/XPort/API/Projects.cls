Include xport

Class XPort.API.Projects Extends Frontier.Router
{

XData UrlMap [ XMLNamespace = "http://github.com/rfns/xport" ]
{
<Routes>
<Route Url="/" Method="GET" Call="ListProjects" />
<Route Url="/:project" Method="DELETE" Call="DeleteProject" />
<Route Url="/:project/xml" Method="GET" Call="GetProjectXML" />
<Route Url="/:project/compile" Method="POST" Call="CompileProject" />
<Route Url="/:project/repair" Method="PATCH" Call="RepairProject" />
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

ClassMethod CompileProject(namespace As %String, project As %String, options As %DynamicObject = {{ "flags": "cku", "hooks": true }}) As %DynamicObject
{
  
  if $data(^CacheTemp.XPort("PendingCompilation")) {
    return %frontier.ThrowException("You need to wait to finish the current compilation before starting a new one.", ..#HTTP423LOCKED)
  }
    
  set options.flags = options.flags_"/nodisplayerror"
  $$$CheckLegacySourceControl(options.hooks)
  
  set ^CacheTemp.XPort("PendingCompilation") = 1

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


  kill ^CacheTemp.XPort("PendingCompilation")
  return {
    "errors": (errors),
    "log": (log)
  }
}

ClassMethod RepairProject(namespace As %String, project As %String) As %DynamicObject
{
  do ##class(XPort.Util.NamespaceCall).RepairProject(namespace, project)
  do %frontier.Status(..#HTTP204NOCONTENT)
  return { "repaired": true }
}

}


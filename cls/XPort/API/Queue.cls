Class XPort.API.Queue Extends Frontier.Router
{

XData UrlMap
{
<Routes>
  <Route Url="/compile"  Method="POST" Call="EnqueueCompilation"/>
  <Route Url="/compile"  Method="DELETE" Call="RemoveQueue"/>
  <Route Url="/compile/stats/:project" Method="GET" Call="GetStats" />
</Routes>
}

ClassMethod EnqueueCompilation(namespace As %String, payload As %DynamicObject) As %DynamicObject
{

  if $data(^CacheTemp.XPort.Queue(payload.project, "running")) {
    return %frontier.ThrowException("There's already a queue running for this project.")
  }

  do ##class(XPort.Util.NamespaceCall).GetProject(namespace, payload.project)
  set count = ##class(XPort.Util.NamespaceCall).CountProjectItems(namespace, payload.project)

  set page = 1
  set list = ""

  set ^CacheTemp.XPort.Queue(payload.project, "running") = 1
  set ^CacheTemp.XPort.Queue(payload.project, "stats", "page") = page
  set ^CacheTemp.XPort.Queue(payload.project, "stats", "count") = count
  set ^CacheTemp.XPort.Queue(payload.project, "stats", "percent") = $System.SQL.FLOOR((100 * (page * 20)) / count)

  while 1 {
    set items = ##class(XPort.Util.NamespaceCall).ListProjectItems(namespace, payload.project, page, 20)
    quit:('$isobject(items) || (items.%Size() = 0))

    set innerPayload = {
      "project": (payload.project),
      "items": [],
      "flags": (payload.flags)
    }

    for i=1:1:items.%Size() - 1  {
      do innerPayload.items.%Push(##class(Port.Util).ItemToPath(items.%Get(i)))
    }

    job CompileNext(innerPayload)::10
    set result = $System.Event.Wait("JobCompile")
    set page = page + 1
  }

  kill ^CacheTemp.XPort.Queue(payload.project, "running")

CompileNext(pload)
  set error = ""
  set response = ##class(XPort.API.Projects.Items).CompileItems(namespace, pload.project, )
  do ##class(Frontier.Dynamic.Serializer).SerializeToStream(.str, response)

  while $isobject(str) && 'str.AtEnd {
    set ^CacheTemp.XPort.Queue(payload.project, "response", page) = $get(^CacheTemp.XPort.Queue(payload.project, "response", page))_response.Read()
  }

  do $System.Event.Signal("JobCompile")
  quit
}

ClassMethod RemoveQueue(project As %String) As %DynamicObject
{
  set existed = $data(^CacheTemp.XPort.Queue(project))
  return { "killed": (existed) }
}

ClassMethod GetStats(project As %String) As %DynamicObject
{
  if '$data(^CacheTemp.XPort.Queue(project)) {
    return %frontier.ThrowException("No compilation tasks were queued for this project.", ..#HTTP404NOTFOUND)
  }

  return {
    "page": (^CacheTemp.XPort.Queue(project, "stats", "page")),
    "percent": (^CacheTemp.XPort.Queue(project, "stats", "percent")),
    "count": (^CacheTemp.XPort.Queue(project, "stats", "count"))
  }
}

}


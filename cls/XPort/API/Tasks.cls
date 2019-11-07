Class XPort.API.Tasks Extends Frontier.Router
{

XData UrlMap
{
<Routes>
  <Route Url="/compile"  Method="POST" Call="StartBackgroundCompilation"/>
  <Route Url="/stats/:project"  Method="DELETE" Call="RemoveCompilationStats"/>
  <Route Url="/stats/:project" Method="GET" Call="GetStats" />
</Routes>
}

ClassMethod StartBackgroundCompilation(namespace As %String, payload As %DynamicObject) As %DynamicObject
{
  
  if $get(^CacheTemp.XPort.Queue(payload.project, "running")) = 1 {
    return %frontier.ThrowException("There's already a compilation task running for this project.")
  }
    
  do ##class(XPort.Util.NamespaceCall).GetProject(namespace, payload.project)
  job ##class(XPort.API.Tasks).batchCompile(namespace, payload)::10
  
  do %frontier.Status(..#HTTP201CREATED)
  do %frontier.Raw()
    
  return ""
}

ClassMethod batchCompile(namespace As %String, payload As %DynamicObject)
{
  set page = 1
  set list = ""
   
  set count = ##class(XPort.Util.NamespaceCall).CountProjectItems(namespace, payload.project)  
  
  set project = payload.project
  set flags = payload.flags  
  
  set ^CacheTemp.XPort.Queue(project, "running") = 1
  set ^CacheTemp.XPort.Queue(project, "stats", "page") = page
  set ^CacheTemp.XPort.Queue(project, "stats", "count") = count
  
  while 1 {
    set list = ##class(XPort.Util.NamespaceCall).ListProjectItems(namespace, payload.project, page, 20)
    set items = list.items
    
    if items.%Size() = 0 {
      set ^CacheTemp.XPort.Queue(project, "stats", "percent") = $System.SQL.FLOOR((100 * (page * 20)) / count)
      quit
    }
        
    set paths = []
    set it = items.%GetIterator()
    
    while it.%GetNext(.index, .item) { 
      do paths.%Push(##class(Port.Util).ItemToPath(item.name)) 
    }
        
    set p = { "items": (paths), "flags": (flags) }
    set response = ##class(XPort.API.Projects.Items).CompileItems(namespace, project, p)
    set ^mtempXPort("aaa") = response
    
    do ##class(Frontier.Dynamic.Serializer).SerializeToStream(.str, response)
    
    set ^CacheTemp.XPort.Queue(project, "stats", "percent") = $System.SQL.FLOOR((100 * (page * 20)) / count)
    
    while $isobject(str) && 'str.AtEnd {
      set ^CacheTemp.XPort.Queue(payload.project, "response", page) = $get(^CacheTemp.XPort.Queue(payload.project, "response", page))_str
    }
    
    set page = page + 1
  }
  
  set ^CacheTemp.XPort.Queue(payload.project, "running") = 0
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


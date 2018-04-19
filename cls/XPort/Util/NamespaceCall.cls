Class XPort.Util.NamespaceCall [ Abstract ]
{

ClassMethod SetItemLock(namespace As %String, itemName As %String, lock As %Boolean) As %Status
{
  set ^mtempXport("ns") = namespace
  new $namespace
  set $namespace = namespace
  
  return ##class(%RoutineMgr).LockItem(itemName, lock)
}

ClassMethod CompileList(namespace As %String, ByRef compileList As %String = "") As %Status
{
  new $namespace
  set $namespace = namespace
  set compileErrors = 0
  
  set sc = $$$OK
  
  do $System.OBJ.CompileList(.compileList, "/nodisplay", .compileErrors)
  
  if compileErrors > 0 { 
    for c=1:1:compileErrors {
      set sc = $$$ADDSC(sc, $$$ERROR(compileErrors(c, "code"), compileErrors(c)))
    }
    $$$QuitOnError(sc)
  }    
  return $$$OK
}

ClassMethod GetRoutine(namespace As %String, routineName As %String)
{
  new $namespace
  set $namespace = namespace
  
  set routine = ##class(%RoutineMgr).%OpenId(routineName)
  if '$isobject(routine) set routine = ##class(%RoutineMgr).%New(routineName)
  
  return routine
}

ClassMethod DeleteItem(namespace As %String, itemName) As %Status
{
  return ##class(%RoutineMgr).Delete(itemName)
}

ClassMethod GetAllProjectItems(namespace As %String, projectName As %String) As %DynamicArray
{
  new $namespace
  set $namespace = namespace
  
  set items = []
  
  set s = ##class(%SQL.Statement).%New()
  $$$ThrowOnError(s.%PrepareClassQuery("%Studio.Project", "ProjectItemsList"))
  set r = s.%Execute(projectName)
  
  while r.%Next(.sc) {   
    $$$ThrowOnError(sc)
    set projectItemName = r.%Get("Name")
    set projectItemType = r.%Get("Type")
    $$$ThrowOnError(##class(%Studio.Project).NormalizeName(.projectItemName, .projectItemType))
    if projectItemType = "CLS" {
      do items.%Push(projectItemName_"."_projectItemType)
    } else {
      do items.%Push(projectItemName)
    }
  }
  
  return items
}

ClassMethod GetProject(namespace As %String, name As %String, ignoreError As %Boolean = 0) As %Studio.Project
{
  new $namespace
  set $namespace = namespace
  
  set project = ##class(%Studio.Project).%OpenId(name)
  if 'ignoreError && '$isobject(project) $$$ThrowStatus($$$ERROR($$$GeneralError, $$$FormatText("Project '%1' does not exist.", name)))
  return project
}

}


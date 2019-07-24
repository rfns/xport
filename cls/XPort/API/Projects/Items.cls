Include (portutils, xport)

Class XPort.API.Projects.Items Extends Frontier.Router
{

XData UrlMap
{
<Routes>
  <Route Url="/sources/pick"  Method="POST" Call="PickItemSources"/>
  <Route Url="/sources/list"  Method="GET" Call="ListItemSources"/>
  <Route Url="/count"  Method="GET" Call="CountItemSources"/>
  <Route Url="/publish" Method="POST" Call="PublishItems"/>
  <Route Url="/remove" Method="POST" Call="RemoveItems"/>
  <Route Url="/delete" Method="POST" Call="DeleteItems"/>
  <Route Url="/paths" Method="GET" Call="GetItemPaths"/>
</Routes>
}

ClassMethod DeleteItems(namespace As %String, projectName As %String(ALIAS="project"), items As %DynamicArray) As %DynamicObject
{
  set project = ##class(XPort.Util.NamespaceCall).GetProject(namespace, projectName)

  set iSC = $$$OK

  set errorOnDelete = []
  set successOnDelete = []

  for i=0:1:items.%Size() - 1 {
    try {
      set sourcePath = items.%Get(i)

      set itemName = ##class(Port.Util).PathToItem(sourcePath, namespace)
      set type = ##class(Port.Util).GetPathType(sourcePath)
      if itemName = "" $$$ThrowStatus($$$ERROR($$$GeneralError, "Could not resolve item name using path "_sourcePath))

      set conflicts = ##class(Port.Util).ListConflicts(project.Name, itemName, type)
      if conflicts '= "" $$$ThrowStatus($$$ERROR($$$GeneralError, "Cannot delete the item "_itemName_" because it's associated to another project. Please check if the following projects depend on it: "_$lts(conflicts, ", ")))

      set routine = ##class(%RoutineMgr).%New(itemName)

      if '$isobject(routine) {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Cannot delete the item: "_itemName_ " because it doesn't exist on the server."))
      } elseif type = "PUBLIC" {
        set path = routine.Code.Filename
        $$$ThrowOnError(routine.Delete(itemName))
        $$$ThrowOnError(##class(XPort.Util.FileRemover).RemoveOne(path))
      } else {
        $$$ThrowOnError(routine.Delete(itemName))
      }
      do successOnDelete.%Push(itemName)
    } catch ex {
      set error = ##class(Frontier.Exception).ToDynamicObject(ex)
      set error.itemName = itemName
      do errorOnDelete.%Push(error)
    }
  }

  $$$ThrowOnError(project.Check())
  $$$ThrowOnError(project.%Save())

  set result = {
    "success": (successOnDelete),
    "hasErrors": ($select(errorOnDelete.%Size() > 0 : "true", 1: "false")),
    "failure": {
      "header": "Failed to delete some items: ",
      "items": (errorOnDelete)
    }
  }
  return result
}

ClassMethod RemoveItems(namespace As %String, project As %String, payload As %DynamicArray) As %Status
{

  set project = ##class(XPort.Util.NamespaceCall).GetProject(namespace, project)

  set successOnRemove = []
  set errorOnRemove = []

  for i=0:1:payload.%Size() - 1 {
    try {
      set sourcePath = payload.%Get(i)
      set itemName = ##class(Port.Util).PathToItem(sourcePath, namespace)
      $$$ThrowOnError(project.RemoveItem(itemName))
      do successOnRemove.%Push(itemName)
    } catch ex {
      set error = ##class(Frontier.Exception).ToDynamicObject(ex)
      set error.itemName = itemName
      do errorOnRemove.%Push(error)
    }
  }

  $$$ThrowOnError(project.%Save())

  set result = {
    "success": (successOnRemove),
    "hasErrors": ($select(errorOnRemove.%Size() > 0 : "true", 1: "false")),
    "failure": {
      "header": ("Failed to remove "_errorOnRemove.%Size()_" items"),
      "items": (errorOnRemove)
    }
  }

  return result
}

ClassMethod PublishItems(namespace As %String, project As %String, payload As %DynamicObject, callLegacySourceControl As %Boolean = 0) As %Status
{
  set project = ##class(XPort.Util.NamespaceCall).GetProject(namespace, project, 1)

  set errorOnPublish = []
  set publishedItems = []
  set compileList = ""
  set compileErrors = ""
  set sc = $$$OK

  set warning = ""
  set sc = $$$ERROR($$$GeneralError, "No valid item has been found.")

  if '$isobject(project) {
    set projectName = %frontier.RouteParameters("project")
    set project = ##class(XPort.Util.NamespaceCall).CreateProject(namespace, projectName)    
    set warning = $$$FormatText("Project did not exist so it was created.", projectName)    
  }

  set payloadIterator = payload.items.%GetIterator()

  while payloadIterator.%GetNext(.i, .file) {
    try {
      set sc = $$$OK
      set source = ""
      set itemName = ##class(Port.Util).PathToItem(file.path, namespace)
      set type = ##class(Port.Util).GetPathType(file.path)
      set itemType = ##class(Port.Util).GetItemType(itemName)
      set fileName = ##class(%File).GetFilename(file.path)
      set binary = 0

      if itemName = "" $$$ThrowStatus($$$ERROR($$$GeneralError, "Could not resolve the origin '"_file.path_"' to a valid item name. Are you sure that '"_fileName_"' is a valid '"_type_"' type?"))

      set conflicts = ##class(Port.Util).ListConflicts(project.Name, itemName)
      if conflicts '= "" $$$ThrowStatus($$$PERROR($$$CannotSaveConflictingItems, itemName, $lts(conflicts), project.Name))

      set itemId = ##class(Port.Util).ResolveItemId(itemName, project.Name)
      set itemExists = project.Items.IsDefined(itemId)
      set code = file.content

      if '$isobject(code) $$$ThrowStatus($$$ERROR($$$GeneralError, "'content' array was not provided for "_itemName))
      set iterator = code.%GetIterator()

      while iterator.%GetNext(.key, .line) {
        set source(0) = key + 1        
        set source(source(0)) = line
      }      

      do ##class(XPort.Util.NamespaceCall).SetItemLock(namespace, itemName, 1)

      $$$CheckLegacySourceControl(callLegacySourceControl)

      if ##class(Port.Util).IsRoutine(itemName) || (itemType = "CSP") {
        set routine = ##class(XPort.Util.NamespaceCall).GetRoutine(namespace, itemName)
        set extension = $$$ucase($piece(itemName, ".", *))
        
        if '$isobject(routine) $$$ThrowStatus($$$ERROR($$$GeneralError, "Invalid item name."))

        if itemType = "CSP" {          
          set binary = $select(file.%IsDefined("binary") : file.binary, 1: ##class(XPort.Util.NamespaceCall).IsBinary(extension))
          set routine.Code.TranslateTable = ##class(Port.Configuration).GetPublicFileInputTranslateTable()
          
          if binary = 1 {
            set routine.Code.TranslateTable = "RAW"
            set routine.Code.StreamFormatWrite = 0
          }
          
          if extension = "CSP" || (extension = "CSR") {
            set compileList(itemName) = ""
          }
        } else {
          set compileList(itemName) = ""
        }

        $$$ThrowOnError($$WriteToStream(routine.Code))
        $$$ThrowOnError(routine.%Save())
      } elseif type = "CLS" {
        // Both the file name and the class name must match.
        $$$ThrowOnError($$AssertClassDefinitionMatch(itemName))

        set stream = ##class(%Stream.GlobalCharacter).%New()
        $$$ThrowOnError($$WriteToStream(stream))

        $$$ThrowOnError(##class(%Compiler.UDL.TextServices).SetTextFromStream(namespace, itemName_".CLS", stream))
        set compileList(itemName) = ""
      }

      if $order(compileList("")) '= "" {
        $$$ThrowOnError(##class(XPort.Util.NamespaceCall).CompileList(namespace, .compileList, payload.compilerOptions))
      }
      
      do ##class(XPort.Util.NamespaceCall).AddItem(namespace, project.Name, itemName)
      
      set code = ##class(XPort.Util.NamespaceCall).RetrieveItemSourceCode(namespace, itemName, .b)      

      if code '= "" {
        do publishedItems.%Push({
          "name": (itemName),
          "content": (code),
          "path": (file.path),
          "binary": (b)
        })
      }
    } catch ex {
      set error = ##class(Frontier.Exception).ToDynamicObject(ex)
      set error.itemName = itemName
      do errorOnPublish.%Push(error)
    }

    do ##class(XPort.Util.NamespaceCall).SetItemLock(namespace, itemName, 0)
  }

  return {
    "success": (publishedItems),
    "hasErrors": ($select(errorOnPublish.%Size() > 0 : "true", 1: "false")),
    "warning": ($case(warning, "": "null", : warning)),
    "failure": {
      "header": "Failed to publish the following items: ",
      "items": (errorOnPublish)
    }
  }

WriteToStream(stream)
  set sc = $$$OK
  do stream.Clear()   

  for i=1:1:source(0) {
    if 'binary {      
      set chunk = $zstrip(source(i), "*C'W",, $c(10,13,9))
      $$$ReturnOnError(stream.WriteLine(chunk))
    } else {
      set chunk = $System.Encryption.Base64Decode(source(i))
      $$$ReturnOnError(stream.Write(chunk))
    }
  }
  do stream.Rewind()
  return $$$OK

AssertClassDefinitionMatch(className)
  for c=1:1:source(0) {
    if $$$lcase($extract(source(c), 1, 6)) = "class " {
      set definingClass = $piece(source(c), " ", 2, 2)
      set className = $piece(className, ".", 1, *-1)

      if definingClass '= className {
        // We cannot allow a class that mismatches its own name to be saved.
        return $$$ERROR($$$GeneralError, $$$FormatText("Attempt to define class named '%1' while the file name is '%2'. Both item and class names must match.", definingClass, className))
      }
      return $$$OK
    }
  }
  if c = source(0) return $$$ERROR($$$GeneralError, $$$FormatText("Item '%1' is not a valid class.", className))
  return $$$OK
}

ClassMethod GetItemPaths(namespace As %String, project As %String) As %DynamicArray
{
  // 999999 Because a single project wouldn't have almost one million of files and this is still faster than
  // using a preload strategy because it avoids roundtrips.
  set list = ##class(XPort.Util.NamespaceCall).ListProjectItems(namespace, project, 1, 999999)
  set paths = []
  
  for i=0:1:list.items.%Size() - 1 {
    set item = list.items.%Get(i)
    set ext = $$$ucase($piece(item.name, ".", *))
    set externalPath = $replace(##class(Port.Util).ItemToPath(item.name), "\", "/")        
    do paths.%Push({ "path": (externalPath), "binary": ($$$FormatBoolean(item.binary)), "name": (item.name) })
  }
  return { "paths": (paths) }
}

ClassMethod ListItemSources(namespace As %String, project As %String, page As %Integer = 1, size As %Integer = 50) As %DynamicObject
{
  set project = ##class(XPort.Util.NamespaceCall).GetProject(namespace, project)   
  
  set list = ##class(XPort.Util.NamespaceCall).ListProjectItems(namespace, project.Name, page, size)
  
  set result = { 
    "success": [],
    "failure": {
      "header": "Failed to get the sources from the following items: ",
      "items": []
    }  
  }  
  
  for i=0:1:list.items.%Size() - 1 {
    set current = list.items.%Get(i)
    set name = current.name
    set index = current.index
   
    try {
      set file = ##class(Port.Util).ItemToPath(name)
      set code = ##class(XPort.Util.NamespaceCall).RetrieveItemSourceCode(namespace, name, .binary)
      
      do result.success.%Push({
        "index": (index),
        "name": (name),
        "content": (code),
        "path": ($$$LTrimSlash(file)),
        "fileName": (##class(%File).GetFilename(file))
      })      
    } catch ex {
      set error = ##class(Frontier.Exception).ToDynamicObject(ex)
      set error.itemName = name
      do result.failure.items.%Push(error)
    }
  }
  
  if list.errors.%Size() > 0 {
    for i=0:1:list.errors.%Size() - 1 {
      set error = list.errors.%Get(i)
      set error.itemName = name
      do result.failure.items.%Push(error)
    }
  }
  
  set result.hasErrors = $$$FormatBoolean(result.failure.items.%Size() > 0)
  set result.more = $$$FormatBoolean(list.more)
  return result
}

ClassMethod PickItemSources(namespace As %String, project As %String, payload As %DynamicObject) As %DynamicObject
{
 
  set project = ##class(XPort.Util.NamespaceCall).GetProject(namespace, project)
  
  set result = { 
    "success": [],
    "failure": {
      "header": "Failed to get the sources from the following items: ",
      "items": []
    }  
  }  

  for i=0:1:payload.files.%Size() - 1 {
    try {
      set filePath = payload.files.%Get(i)           
      set itemName = ##class(Port.Util).PathToItem(filePath, namespace)
      set fileBelongsToProject = ##class(Port.Util).ExistsInProject(project.Name, itemName, "", namespace)
      
      if 'fileBelongsToProject {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Item "_itemName_" is not present in the project '"_%frontier.RouteParameters("project")_"' or does not exist."))
      }
      
      set code = ##class(XPort.Util.NamespaceCall).RetrieveItemSourceCode(namespace, itemName, .binary)

      do result.success.%Push({
        "name": (itemName),
        "content": (code),
        "path": ($$$LTrimSlash(filePath)),
        "fileName": (##class(%File).GetFilename(filePath))
      })
    } catch ex {
      set error = ##class(Frontier.Exception).ToDynamicObject(ex)
      set error.itemName = itemName
      do result.failure.items.%Push(error)
    }
  }
  
  set result.hasErrors = $$$FormatBoolean((result.failure.items.%Size() > 0))
  return result
}

ClassMethod CountItemSources(namespace As %String, project As %String) As %DynamicObject
{
  set count = ##class(XPort.Util.NamespaceCall).CountProjectItems(namespace, project)
  return { "count": (count) }
}

}


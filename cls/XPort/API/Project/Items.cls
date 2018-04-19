Include (portutils, xport)

Class XPort.API.Project.Items Extends Frontier.Router
{

XData UrlMap
{
<Routes>  
  <Route Url="/fetch"  Method="POST" Call="FetchItemsSourceCode"/>
  <Route Url="/publish" Method="POST" Call="PublishItems"/>
  <Route Url="/remove" Method="POST" Call="RemoveItems"/>
  <Route Url="/delete" Method="POST" Call="DeleteItems"/>
  <Route Url="/list" Method="GET" Call="ListProjectItems"/>
 </Routes>
}

ClassMethod DeleteItems(namespace As %String, project As %String, payload As %DynamicObject) As %String
{
 
  set project = ##class(XPort.Util.NamespaceCall).GetProject(namespace, project)
  
  set iSC = $$$OK  
  
  set errorOnDelete = []
  set successOnDelete = []
    
  for i=0:1:payload.items.%Size() - 1 {
    try {
      set sourcePath = payload.items.%Get(i)
      set workspace = ##class(Port.Util).ResolveWorkspaceFromPath(sourcePath)
      set type = ##class(Port.Util).ExtractType(sourcePath, workspace)      
      
      set itemName = ##class(Port.Util).MountItemNameFromSourcePath(sourcePath, namespace)
      if itemName = "" $$$ThrowOnError($$$ERROR($$$GeneralError, "Could not resolve item name using path "_sourcePath))      
      
      set ubiquityList = ##class(Port.Util).ListConflicts(project.Name, itemName, type)
      
      if ubiquityList '= "" {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Cannot delete the item "_itemName_" because it's associated to another project. Please check if the following projects depend on it: "_$lts(ubiquityList, ", ")))
      }
      
      if type = "WEB" {
        $$$ThrowOnError(##class(Port.Util).CSPLogicalToPhysicalPath(itemName, .targetAbsolutePath))
        $$$ThrowOnError(##class(XPort.Util.FileRemover).RemoveOne(targetAbsolutePath))        
        set itemName = targetAbsolutePath     
      } elseif ##class(Port.Util).IsRoutine(itemName) {
        if type = "CLS" set itemName = itemName_".CLS"
        $$$ThrowOnError(##class(%RoutineMgr).Delete(itemName))
      }
      do successOnDelete.%Push(itemName)
    } catch ex {
      set error = ##class(Frontier.Exception).ToDynamicObject(ex)
      set error.name = itemName
      do errorOnDelete.%Push(error)
    }   
  }   
  
  $$$ThrowOnError(project.Check())
  $$$ThrowOnError(project.%Save())  
  
  set result = {
    "oks": (successOnDelete),
    "errors": (errorOnDelete)
  }
  
  return result
}

ClassMethod RemoveItems(namespace As %String, project As %String, payload As %DynamicArray) As %Status
{
    
  set project = ##class(XPort.Util.NamespaceCall).GetProject(namespace, project)
  
  set successOnRemove = []
  set errorOnRemove = []  
  
  for i=0:1:payload.items.%Size() - 1 {
    set sourcePath = payload.items.%Get(i)
    set itemName = ##class(Port.Util).MountItemNameFromSourcePath(sourcePath, namespace)
    
    set sc = project.RemoveItem(itemName)
    
    if $$$ISERR(sc) {
      set error = ##class(Frontier.Exception).ToDynamicObject($$$StatusToException(sc)).error
      set error.name = itemName
      do errorOnRemove.%Push(error)
    } else {  
      do successOnRemove.%Push(itemName)
    }
  }
  
  $$$ThrowOnError(project.%Save())
  
  set result = {
    "oks": (successOnRemove),
    "errors": (errorOnRemove)
  }  
  
  return result
}

ClassMethod PublishItems(namespace As %String, project As %String, payload As %DynamicObject) As %Status
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
    set projectCandidateName = %frontier.RouteParameters("project")
    set warning = "Project "_projectCandidateName_" does not exist and will be created with the same name as this workspace folder, but only after the items are published."
    set project = ##class(%Studio.Project).%New()
    set project.Name = projectCandidateName
  }
  
  set payloadIterator = payload.files.%GetIterator()
  
  while payloadIterator.%GetNext(.i, .file) {
    try {
      set sc = $$$OK
      set source = ""
      set itemName = ##class(Port.Util).MountItemNameFromSourcePath(file.path, namespace)
      set workspace = ##class(Port.Util).ResolveWorkspaceFromPath(file.path)
      set type = ##class(Port.Util).ExtractType(file.path, workspace)
      set fileName = ##class(%File).GetFilename(file.path)
      
      if itemName = "" {
        $$$ThrowOnError($$$ERROR($$$GeneralError, "Could not resolve the origin '"_file.path_"' to a valid item name. Are you sure that '"_fileName_"' is a valid '"_type_"' type?"))
      }
      
      set ubiquityList = ##class(Port.Util).ListConflicts(project.Name, itemName)
      
      if ubiquityList '= "" {
        $$$ThrowOnError($$$PERROR($$$CannotSaveConflictingItems, itemName, $lts(ubiquityList), project.Name))
      }
      
      set itemId = ##class(Port.Util).MountIdFromName(itemName, project.Name)
      set itemExists = project.Items.IsDefined(itemId)
      set itemType = ##class(Port.Util).ResolveItemExtension(itemName)  
      set code = file.content
      
      if '$isobject(code) {
        do %frontier.ThrowException("'content' array was not provided for "_itemName)
      }
      
      set type = ##class(Port.Util).ResolveItemExtension(file.path)
      set iterator = code.%GetIterator()           
      
      while iterator.%GetNext(.key, .line) { 
        set source(0) = key + 1
        set source(source(0)) = line
      }      
      
      do ##class(XPort.Util.NamespaceCall).SetItemLock(namespace, itemName, 1)
      
      if ##class(Port.Util).IsRoutine(itemName) {
        set routine = ##class(XPort.Util.NamespaceCall).GetRoutine(namespace, itemName)
    
        $$$ThrowOnError($$WriteToStream(routine.Code))
        $$$ThrowOnError(routine.%Save())
        
        set compileList(itemName) = ""
      } elseif type = "CLS" {
        // Checks if client is providing correct item name and class definition.
        $$$ThrowOnError($$AssertClassDefinitionMatch(itemName))
        
        set stream = ##class(%Stream.GlobalCharacter).%New()
        $$$ThrowOnError($$WriteToStream(stream))
        
        $$$ThrowOnError(##class(%Compiler.UDL.TextServices).SetTextFromStream(namespace, itemName_".CLS", stream))
        set compileList(itemName) = ""
      } else {      
        $$$ThrowOnError(##class(Port.Util).CSPLogicalToPhysicalPath(itemName, .physicalPath))      
        $$$ThrowOnError(##class(Port.Util).CreateMissingPath(##class(%File).GetDirectory(physicalPath)))
        
        set remoteFile = ##class(%Stream.FileCharacter).%New()
        
        $$$ThrowOnError(remoteFile.LinkToFile(physicalPath))
        $$$ThrowOnError($$WriteToStream(remoteFile))
        $$$ThrowOnError(remoteFile.%Save())      
        
        // Static files are normally not compiled, with the exception of CSP files.
        if type = "CSP" set compileList(itemName) = ""           
      }
      
      if $order(compileList("")) '= "" {        
        $$$ThrowOnError(##class(XPort.Util.NamespaceCall).CompileList(namespace, .compileList))          
      }            
      
      set pSC = project.AddItem(itemName)
      if $$$GETERRORCODE(pSC) '= $$$ProjectIncludesPackage {
        // We don't care if class is owned by a package or not, AddItem checks and prevents item duplication, that's enough for us.
        $$$ThrowOnError(pSC)
      }
      $$$ThrowOnError(..RetrieveItemSourceCode(namespace, workspace, itemName, .code))
      $$$ThrowOnError(project.%Save())      
      
      do publishedItems.%Push({
        "item": (itemName),
        "content": (code),
        "path": (file.path)
      })
    } catch ex {
      set error = ##class(Frontier.Exception).ToDynamicObject(ex)
      set error.name = itemName
      do errorOnPublish.%Push(error)      
    }    
  }   
  
  do ##class(XPort.Util.NamespaceCall).SetItemLock(namespace, itemName, 0)
  
  return {
    "oks": (publishedItems),
    "errors": (errorOnPublish),
    "warning": ($case(warning, "": "null", : warning))
  }      

WriteToStream(stream)
  set sc = $$$OK
  do stream.Clear()
  
  for i=1:1:source(0) {
    if i '= source(0) || (i = source(0) && ($extract(source(i), *-2, *) = $char(13,10))) {
      $$$ReturnOnError(stream.WriteLine(source(i)))
    } else {
      $$$ReturnOnError(stream.Write(source(i)))
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
        return $$$ERROR($$$GeneralError, $$$FormatText("Attempt to define class with name '%1' while item name is '%2'. Both item and class names must match.", definingClass, className))
      }
      return $$$OK
    }    
  }
  if c = source(0) return $$$ERROR($$$GeneralError, $$$FormatText("Item '%1' is not a valid class.", className))
  return $$$OK
}

ClassMethod ListProjectItems(namespace As %String, project As %String) As %DynamicArray
{
  return {
    "items": (%frontier.SQL.Prepare("%Studio.Project:ProjectItemsList").Parameters(project, 1))
  }
}

ClassMethod FetchItemsSourceCode(namespace As %String, project As %String, payload As %DynamicObject) As %DynamicObject
{
 
  set project = ##class(XPort.Util.NamespaceCall).GetProject(namespace, project)
  
  set result = []
  set code = ""
  set all = 0  
  
  set targets = payload.items  
  
  if '$isobject(targets) {
    return %frontier.ThrowException("'targets' array was not provided within the payload.")
  }
    
  if payload.items.%Get(0) = "*" {
    set all = 1
    set payload.items = ##class(XPort.Util.NamespaceCall).GetAllProjectItems(namespace, project.Name)
  }
  
  set success = []
  set errors = []
  
  for i=0:1:payload.items.%Size() - 1 {
    try {
      set itemName = payload.items.%Get(i)    
      if itemName [ payload.workspace {
        set itemName = ##class(Port.Util).MountItemNameFromSourcePath(itemName, namespace)    
      }
    
      set externalPath = ##class(Port.Util).MountItemSourcePath(itemName, payload.workspace)
      
      if all || ('all && ##class(Port.Util).ExistsInProject(project.Name, itemName, "", namespace)) {
         $$$ThrowOnError(..RetrieveItemSourceCode(namespace, payload.workspace, itemName, .code, externalPath))
      } else {
        $$$ThrowStatus($$$ERROR($$$GeneralError, "Item "_itemName_" is not present in the project '"_%frontier.RouteParameters("project")_"' or simply does not exist."))
      }      
        
      do success.%Push({
        "name": (itemName),
        "content": (code),
        "lastChange": ($extract($replace(##class(%RoutineMgr).TS(itemName), " ", "T"), 1, *-3)_"Z"),
        "path": (externalPath),
        "fileName": (##class(%File).GetFilename(externalPath))
      })    
    } catch ex {
      set error = ##class(Frontier.Exception).ToDynamicObject(ex)
      set error.name = itemName
      do errors.%Push(error)
    }
  }
  
  return { 
    "oks": (success),
    "errors": (errors)
  }
}

ClassMethod RetrieveItemSourceCode(namespace As %String, workspacePath As %String, itemName As %String, code As %Stream.Object, Output externalPath As %String = "") As %Status [ Private ]
{

  #dim stream As %Stream.GlobalCharacter  
  
  set skipStaticCode = 0
  set code = []
  
  // If there's no external path, then when are getting it from a item already known by the client.
  if externalPath = "" {
    // In that case no source code must be fetched from the server as it should be the same for both sides.
    // The result is an empty code array signaling it.
    set skipStaticCode = 1        
    set externalPath = ##class(Port.Util).MountItemSourcePath(itemName, workspacePath)
  }     
  
  set pathType = ##class(Port.Util).ExtractType(externalPath, workspacePath)
  
  if pathType = "CLS" {
    $$$ThrowOnError(##class(%Compiler.UDL.TextServices).GetTextAsStream(namespace, itemName, .content))
    set code = $$StreamToArray(content)
  } elseif ##class(Port.Util).IsRoutine(itemName) {
    set routine = ##class(%RoutineMgr).%OpenId(itemName)
    if '$isobject(routine) return $$$ERROR($$$RoutineDoesNotExist, itemName)
    set code = $$StreamToArray(routine.Code)
  } elseif 'skipStaticCode {
    set file = ##class(%Stream.FileCharacter).%New()
    $$$ThrowOnError(##class(Port.Util).CSPLogicalToPhysicalPath(itemName, .physicalPath, namespace))
    $$$ThrowOnError(file.LinkToFile(physicalPath))
    set code = $$StreamToArray(file)
  }   
  
  return $$$OK  
  
StreamToArray(stream)
  set array = []
  
  do stream.Rewind()
  
  while 'stream.AtEnd {
    do array.%Push(stream.ReadLine())    
  }
  return array
}

ClassMethod T() As %Status
{
  do ##class(Frontier.DevTools.FakeAgent).Request("api/xport/DEV/xport-testing/items/fetch", "POST", {
    "workspace": "/home/rubens/projects/xport-testing",
    "items": ["*"]
  }, "Basic "_$System.Encryption.Base64Encode("_system:SYS"), 1)
}

}


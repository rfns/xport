Include (xport, frontier, portutils)

Class XPort.Util.NamespaceCall [ Abstract ]
{

ClassMethod IsBinary(ext As %String) As %Boolean
{
  set ext = $$$ucase(ext)
  if $lf($lfs($$$RoutineGroups_",MD,CSP,CSR,SCSS,LESS,JSX,VUE,CLS,JSON"), ext) return 0
  do ##class(%CSP.StreamServer).FileClassify(ext, .type, .binary)
  return binary
}

ClassMethod SetItemLock(namespace As %String, itemName As %String, lock As %Boolean) As %Status
{
  $$$ChangeNamespace(namespace)
  return ##class(%RoutineMgr).LockItem(itemName, lock)
}

ClassMethod CompileList(namespace As %String, ByRef compileList As %String = "", qspec As %String = "cku") As %Status
{
  $$$ChangeNamespace(namespace)
  set compileErrors = 0

  set sc = $$$OK

  do $System.OBJ.CompileList(.compileList, qspec_"/nodisplay", .compileErrors)

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
  $$$ChangeNamespace(namespace)
  set routine = ##class(%RoutineMgr).%OpenId(routineName)
  if '$isobject(routine) set routine = ##class(%RoutineMgr).%New(routineName)

  return routine
}

ClassMethod DeleteItem(namespace As %String, itemName) As %Status
{
  $$$ChangeNamespace(namespace)
  return ##class(%RoutineMgr).Delete(itemName)
}

ClassMethod ListProjects(namespace As %String) As %DynamicArray
{
  $$$ChangeNamespace(namespace)

  set projects = []

  set s = ##class(%SQL.Statement).%New()
  $$$ThrowOnError(s.%PrepareClassQuery("%Studio.Project", "ProjectList"))
  set c = s.%Execute()

  while c.%Next() {
    set name = c.%Get("Name")
    if name [ "Default" continue
    &sql(SELECT TOP 1 NAME into :item FROM %STUDIO.PROJECTITEM WHERE PROJECT = :name)
    set hasItems = $select(item '= "" : "true", 1: "false")
    do projects.%Push({ "name": (name), "has_items": (hasItems) })
  }

  return {
    "projects": (projects)
  }
}

ClassMethod CountProjectItems(namespace As %String, projectName As %String) As %Integer
{
  $$$ChangeNamespace(namespace)
  
  set count = 0
  set ts = ##class(%SQL.Statement).%ExecDirect(, "call %Studio.Project_ProjectItemsList(?)", projectName)
  while ts.%Next() { set count = count + 1 }
  
  return count
}

ClassMethod ListProjectItems(namespace As %String, projectName As %String, page As %Integer = 1, size As %Integer = 50) As %DynamicArray
{
  $$$ChangeNamespace(namespace)
  
  set items = []

  set s = ##class(%SQL.Statement).%New()
  $$$ThrowOnError(s.%PrepareClassQuery("%Studio.Project", "ProjectItemsList"))  
  set r = s.%Execute(projectName)
  
  set count = ..CountProjectItems(namespace, projectName)   
  
  set result = { "items": [], "errors": [] } 
  set i = 0
  
  // Calculates the page boundaries.
  set limit = page * size
  set offset = limit - (size - 1)

  while r.%Next(.sc) {
    set i = i + 1        
    if i < offset continue
    if i > limit quit
    
    try {                  
      $$$ThrowOnError(sc)      
      
      set name = r.%Get("Name")
      set type = r.%Get("Type")
      set ext = $$$ucase($piece(name, ".", *))
      
      // We are expanding the PKGs already because only the classes matter.
      if type = "PKG" continue      
      
      $$$ThrowOnError(##class(%Studio.Project).NormalizeName(.name, .type))    
      if type = "CLS" set name = name_".cls" set ext = "CLS"
      do result.items.%Push({ "index": (i), "name": (name), "binary": (..IsBinary(ext)) })
    } catch ex {
      set error = ##class(Frontier.Exception).ToDynamicObject(ex)
      do result.errors.%Push({ "index": (i), "error": (error) })
    }
  }
  
  do result.%Set("more", i < count, "boolean")
  return result
}

ClassMethod GetProject(namespace As %String, name As %String, ignoreError As %Boolean = 0) As %Studio.Project
{
  $$$ChangeNamespace(namespace)

  set project = ##class(%Studio.Project).%OpenId(name)
  if $isobject(project) do project.Items.Load()
  if 'ignoreError $$$ThrowOnError(..AssertValidProject(name))  
  return project
}

ClassMethod AddItem(namespace As %String, name As %String, itemName As %String)
{
  $$$ChangeNamespace(namespace)
  
  set project = ..GetProject(namespace, name)
  
  set sc = project.AddItem(itemName)
  
  if $$$GETERRORCODE(sc) '= $$$ProjectIncludesPackage {
    // We don't care if class is owned by a package or not, if that's the error we ignore it.
    $$$ThrowOnError(sc)
  }
  
  $$$ThrowOnError(project.%Save())
}

ClassMethod CreateProject(namespace As %String, name As %String) As %Studio.Project
{
  $$$ChangeNamespace(namespace)
  
  // Checks if the project exists to prevent ID clashes.
  set project = ##class(%Studio.Project).%OpenId(namespace)
  if '$isobject(project) {
    // Nothing found, we are safe to create a new one.
    set project = ##class(%Studio.Project).%New()
    set project.Name = name
    
    // Save the project to make sure it exists even if empty.
    do project.%Save()
  }
    
  // Now load the relationship data into the memory.
  do project.Items.Load()
  return project
}

ClassMethod CompileProject(namespace As %String, name As %String, qspec As %String = "") As %Status
{
  $$$ChangeNamespace(namespace)

  $$$QuitOnError(..AssertValidProject(name, .project))
  return project.Compile(qspec)
}

ClassMethod DeleteProject(namespace As %String, name As %String)
{
  $$$ChangeNamespace(namespace)

  $$$ThrowOnError(..AssertValidProject(name, .project))
  $$$ThrowOnError(##class(%Studio.Project).Delete(name))
}

ClassMethod ExportProjectToXML(namespace As %String, name As %String) As %Stream.Object
{
  $$$ChangeNamespace(namespace)

  set tempFilename = ##class(%File).TempFilename("xml")

  $$$ThrowOnError(..AssertValidProject(name, .project))
  $$$ThrowOnError(project.Export(tempFilename, "/nodisplay/diffexport", 0,.errors))

  set input = ##class(%Stream.FileCharacter).%New()
  set input.TranslateTable = ##class(Port.Configuration).GetPublicFileOutputTranslateTable()
  $$$ThrowOnError(input.LinkToFile(tempFilename))

  set output = ##class(%Stream.GlobalCharacter).%New()
  set input.TranslateTable = ##class(Port.Configuration).GetPublicFileOutputTranslateTable()
  $$$ThrowOnError(output.CopyFrom(input))

  set input = ""
  do ##class(%File).Delete(tempFilename)

  return output
}

ClassMethod GetDocumentReferences(namespace As %String, expression As %String, pattern As %String, includeSystemDocs As %Boolean = 1, wholeWords As %Boolean = 0, caseSensitive As %Boolean = 0, max As %Integer = 50, filter As %String = "", wild As %Boolean = 0) As %Stream.Object
{
  $$$ChangeNamespace(namespace)
  $$$ThrowOnError(##class(Frontier.Shared.Utilities).CallAndCapture("%Studio.Project", "FindInFiles", .output, expression, pattern, includeSystemDocs, wholeWords, caseSensitive, max, filter, wild))
  return output
}

ClassMethod RetrieveItemSourceCode(namespace As %String, itemName As %String, Output isBinary As %Boolean = "") As %Stream.Object
{
  #dim stream As %Stream.GlobalCharacter
  set code = []
  set isBinary = 0

  set externalPath = ##class(Port.Util).ItemToPath(itemName)
  set pathType = ##class(Port.Util).GetPathType($$$LPadSlash(externalPath))
  
  set publicFileOTT = ##class(Port.Configuration).GetPublicFileOutputTranslateTable()  
  set routineOTT = ##class(Port.Configuration).GetRoutineOutputTranslateTable()
  
  $$$ChangeNamespace(namespace)

  if pathType = "CLS" {
    $$$ThrowOnError(##class(%Compiler.UDL.TextServices).GetTextAsStream(namespace, itemName, .content))
    set code = $$StreamToArray(content)
  } elseif ##class(Port.Util).IsRoutine(itemName) {    
    set routine = ##class(%RoutineMgr).%OpenId(itemName)
    if '$isobject(routine) $$$ThrowStatus($$$ERROR($$$RoutineDoesNotExist, itemName))
    set code = $$StreamToArray(routine.Code)
  } else {
    set ext = $$$ucase($piece(itemName, ".", *))
    set csp = ##class(%CSP.Routine).%New($$$LPadProvidedSlash(itemName, "/"))
    set isBinary = $select(isBinary '= "" : isBinary, 1: ..IsBinary(ext))       
    
    if 'isBinary {
      set csp.TranslateTable = publicFileOTT
    } else {
      set csp.TranslateTable = "RAW"
    }         
    set code = $$StreamToArray(csp)
  }

  return code

StreamToArray(stream)
  set array = []

  do stream.Rewind()
  set len = 12000 

  while 'stream.AtEnd {
    if 'isBinary {
      do array.%Push(stream.ReadLine())
    } else {
      do array.%Push($System.Encryption.Base64Encode(stream.Read(.len), 1))
    }
  }
  return array
}

ClassMethod RepairProject(namespace As %String, name As %String)
{
  $$$ChangeNamespace(namespace)
  $$$ThrowOnError(..AssertValidProject(name, .project))
  $$$ThrowOnError(project.Check())
  $$$ThrowOnError(project.%Save())
}

ClassMethod AssertValidProject(name As %String, Output project As %Studio.Project = "") As %Status
{
  set project = ##class(%Studio.Project).%OpenId(name)
  if '$isobject(project) $$$ThrowStatus($$$ERROR($$$GeneralError, $$$FormatText("Project '%1' does not exist.", name)))
  return $$$OK
}

}


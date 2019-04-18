Include xport

Class XPort.Util.NamespaceCall [ Abstract ]
{

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

ClassMethod GetAllProjectItems(namespace As %String, projectName As %String) As %DynamicArray
{
  $$$ChangeNamespace(namespace)
  set items = []

  set s = ##class(%SQL.Statement).%New()
  $$$ThrowOnError(s.%PrepareClassQuery("%Studio.Project", "ProjectItemsList"))
  set r = s.%Execute(projectName)

  set itemList = ""
  set qualifiedClasses = ""

  while r.%Next(.sc) {
    $$$ThrowOnError(sc)
    set projectItemName = r.%Get("Name")
    set projectItemType = r.%Get("Type")
    $$$ThrowOnError(##class(%Studio.Project).NormalizeName(.projectItemName, .projectItemType))
    if projectItemType = "CLS" {
      // Defer the insert to after we check if there's any package to be expanded.
      set qualifiedClasses(projectItemName_".CLS") = 1
    } elseif projectItemType = "PKG" {
      $$$ThrowOnError($System.OBJ.GetPackageList(.pkgd, projectItemName))
      // Found a package, normalize the list and delete any entry that doesn't have the CLS extension.
      set n = "" for  set n = $order(pkgd(n), 1, v)  quit:n=""  continue:v  set pkgd(n_".CLS") = 1 kill pkgd(n)
      merge qualifiedClasses = pkgd
    } else {
      do items.%Push(projectItemName)
    }
  }

  // From this step onwards we won't face any repeated subscript, so we can add the classes safely.
  set name = ""
  for  set name = $order(qualifiedClasses(name)) quit:name=""  do items.%Push(name)

  return items
}

ClassMethod GetProject(namespace As %String, name As %String, ignoreError As %Boolean = 0) As %Studio.Project
{
  $$$ChangeNamespace(namespace)

  set project = ##class(%Studio.Project).%OpenId(name)
  if 'ignoreError $$$ThrowOnError(..AssertValidProject(name))
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
  // Continuação.
  $$$ChangeNamespace(namespace)

  set tempFilename = ##class(%File).TempFilename("xml")

  $$$ThrowOnError(..AssertValidProject(name, .project))
  $$$ThrowOnError(project.Export(tempFilename, "/nodisplay/diffexport", 0,.errors, "RAW"))

  set input = ##class(%Stream.FileCharacter).%New()
  $$$ThrowOnError(input.LinkToFile(tempFilename))

  set output = ##class(%Stream.GlobalCharacter).%New()
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

ClassMethod RetrieveItemSourceCode(namespace As %String, workspacePath As %String, itemName As %String) As %Stream.Object
{
  #dim stream As %Stream.GlobalCharacter
  set code = []

  set externalPath = ##class(Port.Util).MountItemSourcePath(itemName, workspacePath)
  set pathType = ##class(Port.Util).ExtractType(externalPath, workspacePath)

  if pathType = "CLS" {
    $$$ThrowOnError(##class(%Compiler.UDL.TextServices).GetTextAsStream(namespace, itemName, .content))
    set code = $$StreamToArray(content)
  } elseif ##class(Port.Util).IsRoutine(itemName) {
    $$$ChangeNamespace(namespace)
    set routine = ##class(%RoutineMgr).%OpenId(itemName)
    if '$isobject(routine) $$$ThrowStatus($$$ERROR($$$RoutineDoesNotExist, itemName))
    set code = $$StreamToArray(routine.Code)
  } else {
    set file = ##class(%Stream.FileCharacter).%New()
    set file.TranslateTable = "UTF8"
    $$$ThrowOnError(##class(Port.Util).CSPLogicalToPhysicalPath(itemName, .physicalPath, namespace))
    $$$ThrowOnError(file.LinkToFile(physicalPath))
    set code = $$StreamToArray(file)
  }

  return code

StreamToArray(stream)
  set array = []

  do stream.Rewind()

  while 'stream.AtEnd {
    do array.%Push(stream.ReadLine())
  }
  return array
}

ClassMethod AssertValidProject(name As %String, Output project As %Studio.Project = "") As %Status
{
  set project = ##class(%Studio.Project).%OpenId(name)
  if '$isobject(project) $$$ThrowStatus($$$ERROR($$$GeneralError, $$$FormatText("Project '%1' does not exist.", name)))
  return $$$OK
}

}

Include (xport, frontier, portutils)

Class XPort.Util.NamespaceCall [ Abstract ]
{

ClassMethod IsBinary(ext As %String) As %Boolean
{
  if $listfind($listfromstring($$$RoutineGroups_",MD,CSP,CSR,SCSS,LESS,JSX,VUE,CLS,JSON"), ext) return 0
  do ##class(%CSP.StreamServer).FileClassify(ext, .type, .binary)
  return binary
}

ClassMethod SetItemLock(namespace As %String, itemName As %String, lock As %Boolean) As %Status
{
  $$$ChangeNamespace(namespace)
  return ##class(%RoutineMgr).LockItem(itemName, lock)
}

ClassMethod CompileList(namespace As %String, ByRef compileList As %String = "", Output out As %Stream.Object = "", qspec As %String = "cku") As %Status
{
  $$$ChangeNamespace(namespace)
  set compileErrors = 0

  set sc = $$$OK

  // Make sure we don't have extra slashes.
  if $extract(qspec, *) = "/" set qspec = $extract(qspec, 1, *-1)

  // Force the compiler to not display the log.
  if qspec [ "/" && (qspec '[ "/nodisplay") set qspec = qspec_"/nodisplay"
  if qspec '[ "/" && (qspec '[ "-d") set qspec = qspec_"-d"

  $$$QuitOnError($system.OBJ.CompileList(.compileList, qspec, .compileErrors))

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
  set sc = ##class(%RoutineMgr).Delete(itemName)
  if $$$ISERR(sc) {
    $$$ThrowStatus($$$ERROR($$$GeneralError, "Cannot delete the item '"_itemName_ "' because it doesn't exist on the server."))
  }
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

ClassMethod ExportSelectionToXML(namespace As %String, items As %DynamicArray, encoding As %String) As %Stream.Object
{
  $$$ChangeNamespace(namespace)

  do DynamicToList(.list)

  set temp = ##class(%File).TempFilename("xml")
  set stream = ##class(%Stream.FileCharacter).%New()
  set stream.TranslateTable = ##class(%Net.Charset).GetTranslateTable(encoding)
  $$$ThrowOnError(stream.LinkToFile(temp))

  set sc = $system.OBJ.ExportToStream(.list, .stream, "/nodisplay/diffexport", .errlog, encoding)

  if $$$ISERR(sc) {
    do ##class(%File).Delete(temp)
    $$$ThrowStatus(sc)
  }

  return stream

DynamicToList(l)
  for i=0:1:items.%Size() - 1 {
    set l(items.%Get(i)) = ""
  }
  quit
}

ClassMethod ListProjectItemsUsingPattern(namespace As %String, projects As %String, pattern As %String = "") As %DynamicArray
{
  $$$ChangeNamespace(namespace)
  set like = ""
  set startswith = ""
  set projects = $listfromstring(projects)

  set args = 1
  set args(1) = projects

   if pattern '= "" {
     set startswith = "AND NAME LIKE ?"
     set args = 2
     set args(2) = pattern
   }

  set s = ##class(%SQL.Statement).%New()
  $$$ThrowOnError(s.%Prepare("SELECT Name, Type FROM %STUDIO.PROJECTITEM WHERE Project %INLIST ? "_startswith_" ORDER BY PROJECT, TYPE, NAME"))

  set rows = s.%Execute(args...)
  set matches = []

  while rows.%Next() {
    set type = rows.%Get("TYPE")
    set name = rows.%Get("NAME")
    $$$ThrowOnError(##class(%Studio.Project).NormalizeName(.name, .type))
    if ($$$ucase(type) = "CLS") set name = name_".CLS"
    do matches.%Push(name)
  }

  return matches
}

ClassMethod GetDocumentReferences(namespace As %String, expression As %String, pattern As %String, includeSystemDocs As %Boolean = 1, wholeWords As %Boolean = 0, caseSensitive As %Boolean = 0, max As %Integer = 50, filter As %String = "", wild As %Boolean = 0) As %Stream.Object
{
  $$$ChangeNamespace(namespace)
  $$$ThrowOnError(##class(Frontier.Shared.Utilities).CallAndCapture("%Studio.Project", "FindInFiles", .output, expression, pattern, includeSystemDocs, wholeWords, caseSensitive, max, filter, wild))
  return output
}

ClassMethod NormalizeLineBreak(expectedStyle As %String, line As %String) As %String
{
  set matchingStyle = ""

  if line [ $char(13, 10) {
    set matchingStyle = $char(13, 10)
  } elseif line [ $char(10) {
    set matchingStyle = $char(10)
  }

  if expectedStyle = ""  set expectedStyle = matchingStyle


  if expectedStyle '= matchingStyle {
    return $replace(line, matchingStyle, expectedStyle)
  }

  return line
}

ClassMethod RetrieveItemSourceCode(namespace As %String, itemName As %String, encoding As %String, lineBreak As %String = "", Output isBinary As %Boolean = "", Output lastModified As %String = "") As %Stream.Object
{

  #dim stream As %Stream.GlobalCharacter
  set code = []

  set externalPath = ##class(Port.Util).ItemToPath(itemName)
  set pathType = ##class(Port.Util).GetPathType($$$LPadSlash(externalPath))

  $$$ChangeNamespace(namespace)

  if pathType = "CLS" {
    $$$ThrowOnError(##class(%Compiler.UDL.TextServices).GetTextAsStream(namespace, itemName, .content))
    set code = $$StreamToArray(content)
    set lastModified = $$$ToISODate($piece(##class(%RoutineMgr).TS(itemName), ".", 1))
    set isBinary = 0
  } elseif ##class(Port.Util).IsRoutine(itemName) {
    set routine = ##class(%RoutineMgr).%OpenId(itemName)
    if '$isobject(routine) $$$ThrowStatus($$$ERROR($$$RoutineDoesNotExist, itemName))
    set code = $$StreamToArray(routine.Code)
    set lastModified = $$$ToISODate($piece(##class(%RoutineMgr).TS(itemName), ".", 1))
    set isBinary = 0
  } else {
    set ext = $$$ucase($piece(itemName, ".", *))
    set csp = ##class(%CSP.Routine).%New($$$LPadProvidedSlash(itemName, "/"))
    if '$isobject(csp) {
      $$$ThrowStatus($$$ERROR($$$GeneralError, $$$FormatText("Item '%1' has an invalid application path or doesn't belong to namespace %2.", itemName, namespace)))
    }

    set isBinary = ..IsBinary(ext)
    set lastModified = $$$ToISODate(##class(%RoutineMgr).TS(itemName))

    if 'isBinary {
      set csp.TranslateTable = encoding
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
      set line = stream.Read(12000)
      do array.%Push(..NormalizeLineBreak(lineBreak, line))
    } else {
      do array.%Push($system.Encryption.Base64Encode(stream.Read(12000), 1))
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

ClassMethod FindDocuments(namespace As %String, pattern As %String, limit As %Integer = 50) As %DynamicObject
{
  $$$ChangeNamespace(namespace)

  set s = ##class(%SQL.Statement).%New()
  $$$ThrowOnError(s.%PrepareClassQuery("%RoutineMgr", "StudioOpenDialog"))
  set c = s.%Execute(pattern,,,1,1,,,,,1)

  set matches = []

  set appPath = ""

  while c.%Next(.sc) {
    $$$ThrowOnError(sc)

    set name = c.%Get("Name")
    set type = c.%Get("Type")

    if type = 9 || (type = 7) continue
    set rtn = ##class(%RoutineMgr).%New(name)

    if type = 5 {
      if '$isobject(rtn) || ($isobject(rtn) && ((rtn.Namespace '= "") && (rtn.Namespace '= namespace))) {
        set rtn = ""
        continue
      } else {
        set rtn = ""
      }
    }

    do matches.%Push(name)
  }

  return matches
}

ClassMethod AssertValidProject(name As %String, Output project As %Studio.Project = "") As %Status
{
  set project = ##class(%Studio.Project).%OpenId(name)
  if '$isobject(project) $$$ThrowStatus($$$ERROR($$$GeneralError, $$$FormatText("Project '%1' does not exist.", name)))
  return $$$OK
}

}


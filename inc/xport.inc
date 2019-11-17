#define StatusToException(%sc)  ##class(%Exception.StatusException).CreateFromStatus(%sc)
#define ContinueOnError(%sc) set sc = %sc continue:$$$ISERR(sc)
#define ReturnOnError(%sc) set sc = %sc return:$$$ISERR(sc) sc
#define AddAndContinue(%sc) set cSC = %sc set sc = $$$ADDSC(sc, cSC) continue:$$$ISERR(cSC)
#define ChangeNamespace(%ns) new $namespace try { set $namespace = %ns } catch ex { $$$ThrowStatus($$$ERROR($$$GeneralError, "Invalid namespace "_%ns_".")) }
#define CheckLegacySourceControl(%legacy) if %legacy = 1 $$$ThrowOnError(##class(%Studio.SourceControl.Interface).SourceControlCreate($username,"",.created,.flags,.username,"",.reaload,"",.iconStatus))
#define ToISODate(%d) $piece(%d, " ", 1)_"T"_$piece(%d, " ", 2)_".000Z"

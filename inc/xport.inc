#define StatusToException(%sc)  ##class(%Exception.StatusException).CreateFromStatus(%sc)
#define ContinueOnError(%sc) set sc = %sc continue:$$$ISERR(sc)
#define ReturnOnError(%sc) set sc = %sc return:$$$ISERR(sc) sc
#define AddAndContinue(%sc) set cSC = %sc set sc = $$$ADDSC(sc, cSC) continue:$$$ISERR(cSC)
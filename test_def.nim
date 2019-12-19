import macros, math, test_no_vars

macro def(function_signature : untyped, code_block : untyped) : untyped =
    var 
        proc_def = nnkProcDef.newTree()
        proc_return_type : NimNode
        proc_name : NimNode
        proc_generic_params = nnkGenericParams.newTree()
        proc_formal_params  = nnkFormalParams.newTree()
        
        #Pass the proc body to the findDeclarableVariables macro to avoid var/let declarations
        proc_body = nnkStmtList.newTree(
            nnkCall.newTree(
                newIdentNode("findDeclarableVariables"),
                code_block
            )
        )    
    
    let function_signature_kind = function_signature.kind

    #echo astGenRepr function_signature

    if function_signature_kind == nnkCommand or function_signature_kind == nnkObjConstr or function_signature_kind == nnkCall:
        
        var name_with_args : NimNode

        #Missing the return type entirely OR not providing any infos at all
        if function_signature_kind == nnkObjConstr or function_signature_kind == nnkCall:
            name_with_args = function_signature
            proc_return_type = newIdentNode("float")
        else:
            name_with_args   = function_signature[0]
            proc_return_type = function_signature[1]

        let first_statement = name_with_args[0]
        
        #Generics
        if first_statement.kind == nnkBracketExpr:
            for index, entry in first_statement.pairs():
                #Name of function
                if index == 0:
                    proc_name = entry
                    continue

                if entry.kind == nnkExprColonExpr:
                    error "Can't specify generics value \"" & $entry[0].strVal & " : " & $entry[1].strVal & "\" for \"def " & $proc_name.strVal & "\". It is defaulted to be \"SomeNumber\"."
                
                #Generics (for now) can only be SomeNumber
                proc_generic_params.add(
                    nnkIdentDefs.newTree(
                        entry,
                        newIdentNode("SomeNumber"),
                        newEmptyNode()
                    )
                )
        
        #No Generics
        elif first_statement.kind == nnkIdent:
            proc_name = first_statement

        #Formal params
        proc_formal_params.add(proc_return_type)    
        
        let args_block = name_with_args[1..name_with_args.len-1]
    
        for index, statement in args_block.pairs():
            
            var new_arg : NimNode

            #Not specified kind, defaults to float: def sine(a) OR def sine(a 0.0)
            if statement.kind != nnkExprColonExpr:

                #def sine(a)
                if statement.len == 0:
                    new_arg = nnkIdentDefs.newTree(
                        statement,
                        newIdentNode("float"),
                        newEmptyNode()
                    )
                #def sine(a 0.0):
                elif statement.len == 2:
                    new_arg = nnkIdentDefs.newTree(
                        statement[0],
                        newIdentNode("float"),
                        statement[1]
                    )
            
            #def sin(a : float)
            else:
                let arg_name = statement[0]
                let arg_type = statement[1]

                #providing default value
                if arg_type.kind == nnkCommand:
                    if arg_type.len == 2:
                        new_arg = nnkIdentDefs.newTree(
                            arg_name,
                            arg_type[0],
                            arg_type[1]
                        )
                
                #no default value
                else:
                    new_arg = nnkIdentDefs.newTree(
                        arg_name,
                        arg_type,
                        newEmptyNode()
                    )

            proc_formal_params.add(new_arg)
                
        #Add name of func
        proc_def.add(proc_name)

        #Add generics
        if proc_generic_params.len > 0:
            proc_def.add(newEmptyNode())
            proc_def.add(proc_generic_params)
        else:
            proc_def.add(newEmptyNode())
            proc_def.add(newEmptyNode())
        
        #Add formal args
        proc_def.add(proc_formal_params)
        proc_def.add(newEmptyNode())
        proc_def.add(newEmptyNode())
        
        #Add function body (with checks for var/lets macro)
        proc_def.add(proc_body)

        #echo astGenRepr proc_def
        #echo repr proc_def        
             
    else:
        error "Invalid syntax for def"

    return proc_def


expandMacros:
    def mySine1[T](a : T) T:
        b = 0.5
        return sin(a + b)

    def mySine2[T, Y](a : T 0.0, b : Y 0.0) T:
        c = 0.5
        return sin(a + b + c)

    def mySine3(a : float 0.0) float:
        b = 0.5
        return sin(a + b)

    #Defaults return to float
    def mySine4(a : float):
        b = 0.5
        return sin(a + b)

    #This defaults everything in the function signature to float:
    def mySine5(a 0.0, c 0.0):
        b = 0.5
        return sin(a + b + c)
        
echo mySine1(0.34)
echo mySine2(0.34)
echo mySine3(0.34)
echo mySine4(0.34)
echo mySine5(0.34)

#dumpAstGen:
    #[ proc mySine[T : SomeNumber](a : T) : T =
        return sin(a) ]#
    
    #[ proc mySine[T : SomeNumber, Y : SomeNumber](a : T, b : Y) : T =
        return sin(a + b)
    ]#
    #[ proc mySine(a : float = 0.0) : void =
        let b = sin(a)

    proc mySine(a : float = 0.0) : float =
        return sin(a) ]#

#[ dumpAstGen:
    proc testFunc(a : float): float =
        findDeclarableVariables:
          b = 0.3
          return (a * a) + b ]#

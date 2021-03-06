local luaclang = require "luaclang"

describe("luaclang.newParser()", function() 
        it("creates parser object for an available file", function()
                local parser = luaclang.newParser("spec/visit.c")
                assert.are.same('userdata', type(parser))
                parser:dispose()
        end)

        it("fails to create an object for an unavailable file", function()
                assert.has.errors(function()
                        luaclang.newParser("non_existent.c")
                end, "file doesn't exist")
        end)
end)

describe("luaclang.getNullCursor()", function() 
        it("creates null cursor", function() 
                local null_cursor = luaclang.getNullCursor()
                assert.are.same('userdata', type(null_cursor))
        end)       
end)

describe("parser:getCursor()", function() 
        it("creates translation unit cursor", function() 
                local parser = luaclang.newParser("spec/visit.c")
                local cursor = parser:getCursor()
                assert.are.same('userdata', type(cursor))
                parser:dispose()
        end)       
end)

describe("parser:getNumDiagnostics()", function()
        it("obtains the expected number of diagnostics", function()
                local parser = luaclang.newParser("spec/diagnostics.c")
                local num_diags = parser:getNumDiagnostics()
                assert.are.equal(2, num_diags)
                parser:dispose()
        end)
end)

describe("parser:getDiagnostic(idx)", function()
        it("obtains the expected diagnostics", function()
                local parser = luaclang.newParser("spec/diagnostics.c")
                local num_diags = parser:getNumDiagnostics()
                local expected = {
                        "1:1: warning: return type of 'main' is not 'int'",
                        "2:9: error: void function 'main' should not return a value"
                }
                local diags = {}
                for i=1, num_diags do
                        line, column, msg = parser:getDiagnostic(i)
                        table.insert(diags, line .. ':' .. column .. ': ' .. msg)
                end
                assert.are.same(expected, diags)
                parser:dispose()
        end)
        
        it("uses an index that is out of bounds", function()
                local luaclang = require "luaclang"
                local parser = luaclang.newParser("spec/diagnostics.c")
                assert.has.errors(function()
                        line, column, msg = parser:getDiagnostic(3)
                end, "calling 'getDiagnostic' on bad self (argument index out of bounds)")
                parser:dispose()
        end)
end)

--Cursor functions

describe("cursor:getSpelling()", function() 
        it("obtains the expected cursor spelling", function()
                local parser = luaclang.newParser("spec/visit.c")
                local cursor = parser:getCursor()
                local cursor_spelling = cursor:getSpelling()
                assert.are.equals("spec/visit.c", cursor_spelling)
                parser:dispose()
        end)
end)

describe("parser:dispose()", function()
        it("fails when a disposed parser object is used for cursor creation", function()
                local parser = luaclang.newParser("spec/visit.c")
                parser:dispose()
                assert.has.errors(function()
                        local cursor = parser:getCursor()
                end, "calling 'getCursor' on bad self (parser object was disposed)")
                parser:dispose()
        end)
        
        it("obtains the spelling of cursor whose parser object was disposed", function()
                local parser = luaclang.newParser("spec/visit.c")
                local cursor = parser:getCursor()
                parser:dispose()
                assert.has_no.errors(function()
                        local cursor_spelling = cursor:getSpelling()
                end)
                parser:dispose()
        end)
end)

describe("cursor:visitChildren()", function()
        it("returns continue", function()
                local parser = luaclang.newParser("spec/visit.c")
                local cur = parser:getCursor()
                local expected = {
                                        {"outer", "spec/visit.c"},
                                        {"type", "spec/visit.c"}
                                 }
                local children = {}
                cur:visitChildren(function (cursor, parent)
                        local cur_spelling, par_spelling = cursor:getSpelling(), parent:getSpelling()
                        table.insert(children, {cur_spelling, par_spelling})
                        return "continue"
                end)
                assert.are.same(expected, children)
                parser:dispose()
        end)

        it("returns break", function()
                local parser = luaclang.newParser("spec/visit.c")
                local cur = parser:getCursor()
                local expected = {
                                        {"outer", "spec/visit.c"}
                                 }
                local children = {}
                cur:visitChildren(function (cursor, parent)
                        local cur_spelling, par_spelling = cursor:getSpelling(), parent:getSpelling()
                        table.insert(children, {cur_spelling, par_spelling})
                        return "break"
                end)
                assert.are.same(expected, children)
                parser:dispose()
        end)

        it("returns recurse", function()
                local parser = luaclang.newParser("spec/visit.c")
                local cur = parser:getCursor()
                local expected = {
                                        {"outer", "spec/visit.c"},
                                        {"first", "outer"},
                                        {"inner", "outer"},
                                        {"second", "inner"},
                                        {"inner_var", "outer"},
                                        {"inner", "inner_var"},
                                        {"second", "inner"},
                                        {"type", "spec/visit.c"},
                                        {"Integer", "type"},
                                        {"Float", "type"},
                                        {"String", "type"}
                                 }
                local children = {}
                cur:visitChildren(function (cursor, parent)
                        local cur_spelling, par_spelling = cursor:getSpelling(), parent:getSpelling()
                        table.insert(children, {cur_spelling, par_spelling})
                        return "recurse"
                end)
                assert.are.same(expected, children)
                parser:dispose()
        end)

        it("throws an error with undefined return to visitor", function()
                local parser = luaclang.newParser("spec/visit.c")
                local cur = parser:getCursor()
                assert.has.errors(function()
                        cur:visitChildren(function (cursor, parent) 
                                return "unknown"
                        end)
                end, "undefined return to visitor")
                parser:dispose()
        end)

        it("throws an error inside the callback function", function()
                local parser = luaclang.newParser("spec/visit.c")
                local cur = parser:getCursor()
                assert.has.errors(function()
                        cur:visitChildren(function (cursor, parent)
                          error("myerror")
                        end)
                end, "spec/clang_spec.lua:178: myerror")
                parser:dispose()
        end)
 
        it("throws an error if argument supplied is not a function", function()
                local parser = luaclang.newParser("spec/visit.c")
                local cur = parser:getCursor()
                assert.has.errors(function()
                        cur:visitChildren("not a function")
                end, "bad argument #1 to 'visitChildren' (function expected, got string)")
                parser:dispose()
        end)

        it("nested visit children", function()
                local parser = luaclang.newParser("spec/visit.c")
                local cur = parser:getCursor()
                local expected = {
                                        {"outer", "spec/visit.c"},
                                        {"first", "outer"},
                                        {"inner", "outer"},
                                        {"inner_var", "outer"},
                                        {"type", "spec/visit.c"},
                                        {"Integer", "type"},
                                        {"Float", "type"},
                                        {"String", "type"}
                                 }
                local children = {}
                cur:visitChildren(function (cursor, parent)
                        local cur_spelling, par_spelling = cursor:getSpelling(), parent:getSpelling()
                        table.insert(children, {cur_spelling, par_spelling})
                        cursor:visitChildren(function (cursor, parent)
                                local cur_spelling, par_spelling = cursor:getSpelling(), parent:getSpelling()
                                table.insert(children, {cur_spelling, par_spelling})
                                return "continue"
                        end)
                        return "continue"
                end )
                assert.are.same(expected, children) 
                parser:dispose()    
        end)

        it("uses extra params", function()
                local parser = luaclang.newParser("spec/visit.c")
                local cur = parser:getCursor()
                local expected = {
                                        {"outer", "spec/visit.c"},
                                        {"type", "spec/visit.c"}
                                 }
                local children = {}
                cur:visitChildren(function (cursor, parent, children)
                        local cur_spelling, par_spelling = cursor:getSpelling(), parent:getSpelling()
                        table.insert(children, {cur_spelling, par_spelling})
                        return "continue"
                end, children)
                assert.are.same(expected, children)
                parser:dispose()
        end)
end)

describe("cursor:getKind()", function()
        it("obtains the expected cursor kind", function()
                local parser = luaclang.newParser("spec/visit.c")
                local cur = parser:getCursor()
                local expected = {
                        "StructDecl",
                        "EnumDecl"
                }
                local children = {}
                cur:visitChildren(function (cursor, parent)
                        table.insert(children, cursor:getKind())
                        return "continue"
                end)
                assert.are.same(expected, children)    
                parser:dispose() 
        end)
end)

local function get_last_child(cursor)
        local last_child
        cursor:visitChildren(function(cursor, parent)
                last_child = cursor
                return "continue"
        end)
        return last_child
end

describe("cursor:getNumArgs()", function()
        it("obtains the expected number of arguments", function()
                local parser = luaclang.newParser("spec/function.c")
                local cursor = parser:getCursor()
                cursor = get_last_child(cursor)
                local num_args = cursor:getNumArgs()
                assert.are.equals(2, num_args)
                parser:dispose()
        end)

        it("uses an incompatible cursor with getNumArgs()", function()
                local parser = luaclang.newParser("spec/struct.c")
                local cursor = parser:getCursor()
                cursor = get_last_child(cursor)
                assert.has.errors(function()
                        local num_args = cursor:getNumArgs()
                end, "calling 'getNumArgs' on bad self (expect cursor with function kind)")
                parser:dispose()
        end)
end)

describe("cursor:getArgCursor()", function()
        it("obtains the expected arg cursor", function()
                local parser = luaclang.newParser("spec/function.c")
                local cursor = parser:getCursor()
                cursor = get_last_child(cursor)
                local arg_cursor
                assert.has_no.errors(function()
                        arg_cursor = cursor:getArgCursor(2)
                end)
                local arg_cursor_str = arg_cursor:getSpelling()
                assert.are.equals(arg_cursor_str, "b")
                parser:dispose()
        end)

        it("uses a non-integer as index value", function()
                local parser = luaclang.newParser("spec/function.c")
                local cursor = parser:getCursor()
                cursor = get_last_child(cursor)
                assert.has.errors(function()
                        arg_cursor = cursor:getArgCursor(1.2)
                end, "bad argument #1 to 'getArgCursor' (number has no integer representation)")
                parser:dispose()
        end)

        it("uses an index that is out of bounds", function()
                local parser = luaclang.newParser("spec/function.c")
                local cursor = parser:getCursor()
                cursor = get_last_child(cursor)
                assert.has.errors(function()
                        arg_cursor = cursor:getArgCursor(7)
                end, "calling 'getArgCursor' on bad self (argument index out of bounds)")
                parser:dispose()
        end)

        it("uses an incompatible cursor with getArgCursor()", function()
                local parser = luaclang.newParser("spec/struct.c")
                local cursor = parser:getCursor()
                cursor = get_last_child(cursor)
                assert.has.errors(function()
                        local arg_type = cursor:getArgCursor(1)
                end, "calling 'getArgCursor' on bad self (expect cursor with function kind)")
                parser:dispose()
        end)
end)

describe("cursor:isFunctionInlined()", function()
        it("identifies an inline function", function()
                local parser = luaclang.newParser("spec/function_inline.c")
                local cursor = parser:getCursor()
                cursor = get_last_child(cursor)
                assert.is_true(cursor:isFunctionInlined())
                parser:dispose()
        end)

        it("identifies a non-inline function", function()
                local parser = luaclang.newParser("spec/function.c")
                local cursor = parser:getCursor()
                cursor = get_last_child(cursor)
                assert.is_false(cursor:isFunctionInlined())
                parser:dispose()
        end)

        it("uses an incompatible cursor with isInlineFunction", function()
                local parser = luaclang.newParser("spec/struct.c")
                local cursor = parser:getCursor()
                cursor = get_last_child(cursor)
                assert.has.errors(function()
                        local is_inline = cursor:isFunctionInlined()
                end, "calling 'isFunctionInlined' on bad self (expect cursor with function kind)")
                parser:dispose()
        end)
end)

local function get_innermost_children(cursor)
        local last_member
        cursor:visitChildren(function(cursor, parent)
                last_member = parent   
                return "recurse"                     
        end)
        return last_member
end

describe("cursor:getEnumValue()", function()
        it("obtains the correct integral value of the EnumConstantDecl", function()
                local parser = luaclang.newParser("spec/enum.c")
                local cursor = parser:getCursor()  
                cursor = get_last_child(cursor)
                local last_enumconst = get_innermost_children(cursor)
                local enum_value = last_enumconst:getEnumValue()
                assert.are.equal(7, enum_value)
                parser:dispose()
        end)

        it("uses an incompatible cursor with getEnumValue()", function()
                local parser = luaclang.newParser("spec/struct.c")
                local cursor = parser:getCursor()
                cursor = get_last_child(cursor)
                assert.has.errors(function()
                        local enum_value = cursor:getEnumValue()
                end, "calling 'getEnumValue' on bad self (expect cursor with enum constant kind)")
                parser:dispose()
        end)
end)

describe("cursor:getStorageClass()", function()
        it("obtains the correct storage class specifer", function()
                local parser = luaclang.newParser("spec/function.c")
                local cursor = parser:getCursor()  
                cursor = get_last_child(cursor)
                local storage_class = cursor:getStorageClass()
                assert.are.equal("extern", storage_class)
                parser:dispose()
        end)

        it("obtains none if there is no storage class specified", function()
                local parser = luaclang.newParser("spec/function_inline.c")
                local cursor = parser:getCursor()  
                cursor = get_last_child(cursor)
                local storage_class = cursor:getStorageClass()
                assert.are.equal("none", storage_class)
                parser:dispose()
        end)
end)

describe("cursor:isBitField()", function()
        it("succeeds in identifying a bit field", function()
                local parser = luaclang.newParser("spec/struct.c")
                local cursor = parser:getCursor()  
                cursor = get_last_child(cursor)
                local last_member = get_innermost_children(cursor)
                assert.is_true(last_member:isBitField())
                parser:dispose()
        end)

        it("uses an incompatible cursor with isBitField()", function()
                local parser = luaclang.newParser("spec/struct.c")
                local cursor = parser:getCursor()
                cursor = get_last_child(cursor)
                assert.has.errors(function()
                        local is_bit_field = cursor:isBitField()
                end, "calling 'isBitField' on bad self (expect cursor with struct/union field kind)")
                parser:dispose()
        end)
end)

describe("cursor:getBitFieldWidth()", function()
        it("obtains the expected bit field width", function()
                local parser = luaclang.newParser("spec/struct.c")
                local cursor = parser:getCursor()  
                cursor = get_last_child(cursor)
                local last_member = get_innermost_children(cursor)
                assert.are.equal(9, last_member:getBitFieldWidth())
                parser:dispose()
        end)

        it("uses an incompatible cursor with getBitFieldWidth()", function()
                local parser = luaclang.newParser("spec/enum.c")
                local cursor = parser:getCursor()
                cursor = get_last_child(cursor)
                assert.has.errors(function()
                        local bit_field_width = cursor:getBitFieldWidth()
                end, "calling 'getBitFieldWidth' on bad self (expect cursor with struct/union field kind that is a bit field)")
                parser:dispose()
        end)
end)

describe("cursor:getTypedefUnderlyingType()", function()
        it("obtains the expected typedef underlying type", function()
                local parser = luaclang.newParser("spec/typedef.c")
                local cursor = parser:getCursor()  
                cursor = get_last_child(cursor)
                local underlying_type
                assert.has_no.errors(function()
                        underlying_type = cursor:getTypedefUnderlyingType()
                end)
                underlying_type_str = underlying_type:getSpelling()
                assert.are.equal("GROUP *", underlying_type_str)
                parser:dispose()
        end)

        it("uses an incompatible cursor with getTypedefUnderlying()", function()
                local parser = luaclang.newParser("spec/enum.c")
                local cursor = parser:getCursor()
                cursor = get_last_child(cursor)
                assert.has.errors(function()
                        local underlying_type = cursor:getTypedefUnderlyingType()
                end, "calling 'getTypedefUnderlyingType' on bad self (expect cursor with typedef kind)")
                parser:dispose()
        end)
end)

describe("cur1:equals(cur2)", function()
        it("returns true for equal cursors", function()
                local parser = luaclang.newParser("spec/struct.c")
                local c1, c2 = parser:getCursor(), parser:getCursor()   
                assert.is_true(c1:equals(c2))
        end)

        it("returns false for unequal cursors", function()
                local parser = luaclang.newParser("spec/struct.c")
                local cursor = parser:getCursor()   
                local first_decl
                cursor:visitChildren(function(cursor, parent)
                        first_decl = cursor
                        return "break"
                end)
                assert.is_false(first_decl:equals(cursor))
        end)
end)

describe("cur:getCursorDefinition()", function()
        it("returns the cursor definition", function()
                local parser = luaclang.newParser("spec/forward_declaration.c")
                local cursor = parser:getCursor()  
                local expected = {"a", "j"} 
                local definition = {}
                local first_decl
                cursor:visitChildren(function(cursor, parent)
                        first_decl = cursor
                        return "break"
                end)
                local def_cur = first_decl:getCursorDefinition()
                def_cur:visitChildren(function(cursor, parent)
                        table.insert(definition, cursor:getSpelling())
                        return "recurse"
                end)
                assert.are.same(expected, definition)
        end)
end)

--Type functions

describe("cursor:getType()", function() 
        it("creates a type object", function() 
                local parser = luaclang.newParser("spec/function.c")
                local cursor = parser:getCursor()   
                local cursor_type = cursor:getType()             
                assert.are.same('userdata', type(cursor_type))
                parser:dispose()
        end)       
end)

describe("cursor_type:getSpelling()", function() 
        it("obtains the expected type spelling", function()
                local parser = luaclang.newParser("spec/function.c")
                local cursor = parser:getCursor()
                cursor = get_last_child(cursor)
                local cursor_type = cursor:getType()
                local cursor_type_spelling = cursor_type:getSpelling()
                assert.are.equals("void (float, float *)", cursor_type_spelling)
                parser:dispose()
        end)
end)

describe("cursor_type:getResultType()", function()
        it("obtains the expected result type", function()
                local parser = luaclang.newParser("spec/function.c")
                local cursor = parser:getCursor()
                cursor = get_last_child(cursor)
                local cursor_type = cursor:getType()
                local result_type = cursor_type:getResultType()
                local result_type_str = result_type:getSpelling()
                assert.are.equals("void", result_type_str)
                parser:dispose()
        end)

        it("uses an incompatible type object with getResultType()", function()
                local parser = luaclang.newParser("spec/struct.c")
                local cursor = parser:getCursor()
                cursor = get_last_child(cursor)
                local cursor_type = cursor:getType()
                assert.has.errors(function()
                        local result_type = cursor_type:getResultType()
                end, "calling 'getResultType' on bad self (expect type object with function kind)")
                parser:dispose()
        end)
end)

describe("cursor_type:getArgType()", function()
        it("obtains the expected arg type", function()
                local parser = luaclang.newParser("spec/function.c")
                local cursor = parser:getCursor()
                cursor = get_last_child(cursor)
                local cursor_type = cursor:getType()
                local arg_type
                assert.has_no.errors(function()
                        arg_type = cursor_type:getArgType(2)
                end)
                local arg_type_str = arg_type:getSpelling()
                assert.are.equals("float *", arg_type_str)
                parser:dispose()
        end)

        it("uses a non-integer as index value", function()
                local parser = luaclang.newParser("spec/function.c")
                local cursor = parser:getCursor()
                cursor = get_last_child(cursor)
                local cursor_type = cursor:getType()  
                assert.has.errors(function()
                        arg_type = cursor_type:getArgType(1.2)
                end, "bad argument #1 to 'getArgType' (number has no integer representation)")
                parser:dispose()
        end)
        
        it("uses an incompatible type object with getArgType()", function()
                local parser = luaclang.newParser("spec/struct.c")
                local cursor = parser:getCursor()
                cursor = get_last_child(cursor)
                local cursor_type = cursor:getType()
                assert.has.errors(function()
                        local arg_type = cursor_type:getArgType(1)
                end, "calling 'getArgType' on bad self (expect type object with function kind)")
                parser:dispose()
        end)
end)

describe("cursor_type:getArrayElementType()", function()
        it("obtains the expected array type", function()
                local parser = luaclang.newParser("spec/array.c")
                local cursor = parser:getCursor()
                cursor = get_last_child(cursor)
                local cursor_type = cursor:getType()
                local arr_type
                assert.has_no.errors(function()
                        arr_type = cursor_type:getArrayElementType()
                end)
                local arr_type_str = arr_type:getSpelling()
                assert.are.equals("int", arr_type_str)
                parser:dispose()
        end)

        it("uses an incompatible type object with getArrayElementType()", function()
                local parser = luaclang.newParser("spec/pointer.c")
                local cursor = parser:getCursor()
                cursor = get_last_child(cursor)
                local cursor_type = cursor:getType()
                assert.has.errors(function()
                        local arr_type = cursor_type:getArrayElementType()
                end, "calling 'getArrayElementType' on bad self (expect type object with array kind)")
                parser:dispose()
        end)
end)

describe("cursor_type:getArraySize()", function()
        it("obtains the expected size", function()
                local parser = luaclang.newParser("spec/array.c")
                local cursor = parser:getCursor()
                cursor = get_last_child(cursor)
                local cursor_type = cursor:getType()
                local arr_size
                assert.has_no.errors(function()
                        arr_size = cursor_type:getArraySize()
                end)
                assert.are.equals(10.0, arr_size)
                parser:dispose()
        end)

        it("uses an incompatible type object with getArraySize()", function()
                local parser = luaclang.newParser("spec/pointer.c")
                local cursor = parser:getCursor()
                cursor = get_last_child(cursor)
                local cursor_type = cursor:getType()
                assert.has.errors(function()
                        local arr_size = cursor_type:getArraySize()
                end, "calling 'getArraySize' on bad self (expect type object with array kind)")
                parser:dispose()
        end)
end)

describe("cursor_type:getPointeeType()", function()
        it("obtains the expected type", function()
                local parser = luaclang.newParser("spec/pointer.c")
                local cursor = parser:getCursor()
                cursor = get_last_child(cursor)
                local cursor_type = cursor:getType()
                local pointee_type
                assert.has_no.errors(function()
                        pointee_type = cursor_type:getPointeeType()
                end)
                local pointee_type_str = pointee_type:getSpelling()
                assert.are.equals("double", pointee_type_str)
                parser:dispose()
        end)

        it("uses an incompatible type object with getPointeeType()", function()
                local parser = luaclang.newParser("spec/array.c")
                local cursor = parser:getCursor()
                cursor = get_last_child(cursor)
                local cursor_type = cursor:getType()
                assert.has.errors(function()
                        local pointee_type = cursor_type:getPointeeType()
                end, "calling 'getPointeeType' on bad self (expect type object with pointer kind)")
                parser:dispose()
        end)
end)

describe("cursor_type:getTypeKind()", function() 
        it("obtains type kind", function() 
                local parser = luaclang.newParser("spec/pointer.c")
                local cursor = parser:getCursor()  
                cursor = get_last_child(cursor)
                local cursor_type = cursor:getType()             
                assert.are.same('Pointer', cursor_type:getTypeKind())
                parser:dispose()
        end)       
end)

describe("cursor_type:getNumArgTypes()", function() 
        it("obtains number of arguments", function() 
                local parser = luaclang.newParser("spec/function_pointer.c")
                local cursor = parser:getCursor()  
                cursor = get_last_child(cursor)
                local cursor_type = cursor:getType()      
                local func_pointer = cursor_type:getPointeeType()       
                assert.are.same(1, func_pointer:getNumArgTypes())
                parser:dispose()
        end)       

        it("uses an incompatible type object with getPointeeType()", function()
                local parser = luaclang.newParser("spec/array.c")
                local cursor = parser:getCursor()
                cursor = get_last_child(cursor)
                local cursor_type = cursor:getType()
                assert.has.errors(function()
                        local pointee_type = cursor_type:getNumArgTypes()
                end, "calling 'getNumArgTypes' on bad self (expect type object with function kind)")
                parser:dispose()
        end)
end)

describe("cursor_type:getTypeDeclaration()", function() 
        it("obtains the cursor", function() 
                local parser = luaclang.newParser("spec/typedecl.c")
                local cursor = parser:getCursor()  
                local struct_decl
                cursor:visitChildren(function (cursor, parent)
                        struct_decl = cursor
                        return "break"
                end)
                cursor = get_last_child(cursor)
                local cursor_type = cursor:getTypedefUnderlyingType()
                local type_decl = cursor_type:getTypeDeclaration() 
                assert.is_true(struct_decl:equals(type_decl))    
        end)       
end)
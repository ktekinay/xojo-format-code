'
' Format Xojo code in the currently opened method
'
' Version: 0.2.1
' Author: Jeremy Cowgar <jeremy@cowgar.com>
' Contributors: 
' 

'
' User Preferences:
'

Dim DoDebug As Boolean
Dim KeywordsToCapitalize() As String

' Appends debug information to the end of the editor. This should be
' set to true only for those working on Code Formatter.
DoDebug = False

' Keywords that you want Code Formatter to correct the case on. By default, all
' keywords and pragmas are listed
KeywordsToCapitalize = Array("AddHandler", "AddressOf", "Array", "As", "Assigns", _
"Break", "ByRef", "ByVal", "CType", "Call", "Case", "Catch", "Const", "Continue", _
"Declare", "Dim", "Do", "Loop", "DownTo", "Each", "Else", "End", "Enum", "Exception", _
"Exit", "Extends", "False", "Finally", "For", "Next", "Function", "GOTO", "GetTypeInfo", _
"If", "Then", "In", "Is", "IsA", "Lib", "Loop", "Next", "Nil", "Optional", "ParamArray", _
"Raise", "RaiseEvent", "Redim", "Rem", "RemoveHandler", "Return", "Select", "Case", "Soft", _
"Static", "Step", "Structure", "Sub", "Super", "Then", "To", "True", "Try", "Until", _
"Wend", "While", "#If", "#ElseIf", "#EndIf", "#Pragma", "DebugBuild", "RBVersion", _
"RBVersionString", "Target32Bit", "Target64Bit", "TargetBigEndian", "TargetCarbon", _
"TargetCocoa", "TargetHasGUI", "TargetLinux", "TargetLittleEndian", _
"TargetMacOS", "TargetMachO", "TargetWeb", "TargetWin32", "TargetX86", _
"BackgroundTasks", "BoundsChecking", "BreakOnExceptions", "DisableAutoWaitCursor", _
"DisableBackgroundTasks", "DisableBoundsChecking", "Error", "NilObjectChecking", _
"StackOverflowChecking", "Unused", "Warning", "X86CallingConvention", "Boolean", _
"CFStringRef", "CString", "Currency", "Delegate", "Double", "Int16", "Int32", "Int64", _
"Int8", "Integer", "OSType", "PString", "Ptr", "Short", "Single", "String", _
"Structure", "UInt16", "UInt32", "UInt64", "UInt8", "UShort", "WindowPtr", _
"WString", "XMLNodeType")

'
' Code Formatting Code
'

Dim SpecialCharacters() As String
SpecialCharacters = Array("<", ">", "<>", ">=", "<=", "=", "+", "-", "*", "/", _
"^", "(", ")", ",", ":")

'
' Helper functions
'

Function IsASpecial(value As String) As Boolean
Return (SpecialCharacters.IndexOf(value) > -1)
End Function

Function IsANumber(value As String) As Boolean
Dim hasDecimal As Boolean = False

For i As Integer = 1 To value.Len
Dim chCode As Integer
chCode = Asc(value.Mid(i, 1))

If i = 1 And (chCode = 43 Or chCode = 45) Then
' Good

ElseIf chCode >= 48 And chCode <= 57 Then
' Good

ElseIf chCode = 46 And hasDecimal = False Then
' Good
hasDecimal = True

Else
Return False
End If
Next

Return True
End Function

Function IsAString(value As String) As Boolean
Return (value.Left(1) = """" And value.Right(1) = """")
End Function

'
' Represent a single token
'
Class Token
Const Keyword = 1
Const Identifier = 2
Const Number = 3
Const Special = 4
Const NewLine = 5
Const StringLiteral = 6

Dim Value As String
Dim Type As Integer

Sub Constructor(v As String)
Dim capitalizeIndex As Integer = KeywordsToCapitalize.IndexOf(v)

If capitalizeIndex > -1 Then
Value = KeywordsToCapitalize(capitalizeIndex)
Type = Keyword

Else
Value = v

If Value = EndOfLine Then
Type = NewLine

ElseIf IsASpecial(Value) Then
Type = Special

ElseIf IsANumber(Value) Then
Type = Number

ElseIf IsAString(Value) Then
Type = StringLiteral

Else
Type = Identifier
End If
End If
End Sub
End Class

'
' Convert a string into a stream of tokens.
'
Class Tokenizer
Dim Tokens() As Token
Dim Code As String
Dim CodeLength As Integer

' Parsing state variables
Private mCurrentPosition As Integer
Private mTokenStartPosition As Integer
Private mInString As Boolean

Sub MaybeAddToken()
If mCurrentPosition <= mTokenStartPosition Then
Return
End If

Dim tok As Token = New Token(Trim(Code.Mid(mTokenStartPosition, _
mCurrentPosition - mTokenStartPosition)))

If tok.value.len > 0 Then
Tokens.Append(tok)
End If

mTokenStartPosition = mCurrentPosition + 1
End Sub

Sub AddToken(value As String)
Tokens.Append(New Token(value))

mTokenStartPosition = mCurrentPosition + 1
End Sub

Function Tokenize(sourceCode As String) As Boolean
Code = sourceCode
CodeLength = sourceCode.Len

Redim Tokens(-1)
mCurrentPosition = 0
mTokenStartPosition = 0
mInString = False

While mCurrentPosition <= CodeLength
Dim ch As String = Code.Mid(mCurrentPosition, 1)
Dim nextCh As String

If mCurrentPosition < CodeLength Then
nextCh = Code.Mid(mCurrentPosition + 1, 1)
End If

If mInString Then
If ch = """" Then
If mCurrentPosition < CodeLength And Code.Mid(mCurrentPosition + 1, 1) = """" Then
' Increment past the next quote, it is a double quote
mCurrentPosition = mCurrentPosition + 1

Else
mInString = False

AddToken(Trim(Code.Mid(mTokenStartPosition, mCurrentPosition - mTokenStartPosition + 1)))
End If
End If

Else
Select Case ch
Case """"
mInString = True

Case " "
MaybeAddToken

Case "+", "-"
' Could be a plus symbol or a negative number. This detection logic isn't the best...
If Asc(nextCh) < 48 Or Asc(nextCh) > 57 Then
' Next character is not a number, add this token as a math operation of its own
MaybeAddToken

AddToken(ch)
End If

Case "(", ")", ",", "*", "^", ":", "=", EndOfLine
MaybeAddToken

AddToken(ch)

Case "_"
' Only process the _ character as an individual token if it is the start of a token
' and it is followed by a space, EndOfLine or comment character
If mCurrentPosition = mTokenStartPosition And _
(nextCh = EndOfLine Or nextCh = " " Or nextCh = "'") Then
MaybeAddToken

AddToken(ch)
End If

Case "/"
MaybeAddToken

' We could have // which indicates a comment and should be a single token, not
' two forward slash tokens.
If nextCh = "/" Then
mCurrentPosition = mCurrentPosition + 1

AddToken("//")

Else
AddToken("/")
End If

Case "<", ">" 
MaybeAddToken

' We could have <>, >=, <=
If nextCh = ">" Or nextCh = "<" Or nextCh = "=" Then
mCurrentPosition = mCurrentPosition + 1

AddToken(ch + nextCh)

Else
AddToken(ch)

End if
End Select
End If

mCurrentPosition = mCurrentPosition + 1
Wend

MaybeAddToken

Return True
End Function
End Class

'
' StringWriter - Take a stream of tokens and write them to a string
'
Class StringWriter
Dim Tokens() As Token
Dim DebugString As String
Dim mRow As Integer
Dim mColumn As Integer
Private mResult As String

Private Sub AddSpace()
mColumn = mColumn + 1
mResult = mResult + " "
End Sub

Private Sub AddString(value As String)
mColumn = mColumn + value.Len
mResult = mResult + value
End Sub

Private Sub AddEndOfLine()
mResult = mResult + EndOfLine
mColumn = 0
mRow = mRow + 1
End Sub

Function Format(theTokens() As Token) As String
Dim i As Integer
Dim tok, lastTok, nextTok As Token = Nil

mRow = 1
mColumn = 0
mResult = ""

Tokens = theTokens

For i = 0 To Tokens.UBound
tok = Tokens(i)
If i < Tokens.UBound Then
nextTok = Tokens(i + 1)

Else
nextTok = Nil
End If

If DoDebug Then
DebugString = DebugString + "' Token: '" + tok.Value + "', Type: " + Str(tok.Type) + EndOfLine
End If

Select Case tok.Value
Case EndOfLine
AddEndOfLine

Else
AddString(tok.Value)
End Select

' Add a space between tokens, if necessary
If mColumn > 0 Then
If nextTok <> Nil Then
If tok.Type = Token.Special And nextTok.Value = "(" Then
AddSpace
ElseIf nextTok.Value = "(" Then
' Do nothing
ElseIf nextTok.Value = ")" Then
' Do nothing
ElseIf tok.Value <> "(" Then
AddSpace
End If
End If
End If

lastTok = tok
Next

Return Trim(mResult)
End Function
End Class

'
' Actual program to interact with Xojo IDE to tokenize and format code
'

Sub Main()
Dim code As String

' If the editor as text selected, assume the user wants to format only the
' selected text. Otherwise, format the entire editor content

If SelLength > 0 Then
code = SelText

Else
code = Text
End If

Dim tokenize As New Tokenizer
Dim writer As New StringWriter

If tokenize.Tokenize(code) = False Then
Call ShowDialog("Error", "Could not convert the code into a valid stream of tokens", "OK")
Return
End If

Dim result As String = writer.Format(tokenize.Tokens)

If DoDebug Then
result = result + EndOfLine + EndOfLine + writer.DebugString
End If

If SelLength > 0 Then
SelText = result

Else
Text = result
End If
End Sub

Main()
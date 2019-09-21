; --- SETTINGS ---
FileEncoding, UTF-8

; --- VARIABLE DECLARATION AND DEFINITION ---
isGoingThroughAnElement := false
element := ""

isGoingThroughJavascript := false
javascript := ""
jsByteToSeekBackTo := -1
cssLinkByteToSeekBackTo := -1
jsLinkByteToSeekBackTo := -1

isGoingThroughFooter := false
footer := ""

lineCounter := 0
FileSelectFile, indexFile, 3, %A_WorkingDir%, Selecione o ficheiro 'index', HTML (*.html)
if indexFile =
{
    MsgBox I can't work unless you select a file
    ExitApp
}
global indexFileDir := ""
SplitPath, indexFile, indexFileName, indexFileDir
logText := logText . "Backing up the file...`r`n"
GuiControl, Text, Log, %logText%
if !InStr(FileExist(indexFileDir . "\Backup"), "D")
{
    FileCreateDir, %indexFileDir%\Backup
}
FileCopy, %indexFile%, %indexFileDir%\Backup

lineTotal := 0
Loop, Read, %indexFile%
{
    lineTotal = %A_Index%
}

global bannedNumbersList := []
global numOfGUIDs := 0
Loop, Read, guidList.txt
{
    numOfGUIDs = %A_Index%
}

indexTempFile := FileOpen("index.tmp", "w")
if !indexTempFile
{
    MsgBox Can't open "%indexTempFile%" for writing.
    ExitApp
}

global logText :=
; --- WINDOW SETUP ---
Gui, Margin, 5, 5
Gui, Font, s14 Bold
Gui, Add, Text, , Humanising %indexFileName%...
Gui, Add, Progress, w440 h20 vProgressBar Range0-%lineTotal%
Gui, Font, s10 w1
Gui, Add, Edit, r10 vLog w440 ReadOnly
Gui, Show, AutoSize, JotForm Humanising Script
windowID := WinExist("JotForm Humanising Script")
ControlGet, LogID, Hwnd,, Log, ahk_id %windowID%

; --- FUNCTIONS ---
Loop, Read, %indexFile%, %indexTempFile%
{
    if(RegExMatch(A_LoopReadLine, "(<link.*type=""text\/css"")") && cssLinkByteToSeekBackTo = -1) ; On the first CSS link, it grabs the byte it's on in the file to later append custom CSS files, if needed
    {
        cssLinkByteToSeekBackTo := indexTempFile.Tell()
    }
    if(RegExMatch(A_LoopReadLine, "(<script.*type=""text\/javascript"".*<\/script>)") && jsLinkByteToSeekBackTo = -1) ; On the first JS link, it grabs the byte it's on in the file to later append custom JS files, if needed
    {
        jsLinkByteToSeekBackTo := indexTempFile.Tell()
    }
    if(RegExMatch(A_LoopReadLine, "(?<!<li)<script type=(?!(.*<\/script>)|([\s\S]*?<\/li>))") && isGoingThroughAnElement = 0)
    {
        isGoingThroughJavascript := true
        if(jsByteToSeekBackTo = -1)
        {
            jsByteToSeekBackTo := indexTempFile.Tell()
        }
    }
    else if(RegExMatch(A_LoopReadLine, "<li ") && isGoingThroughJavascript = 0)
    {
        isGoingThroughAnElement := true
    }
    else if(InStr(A_LoopReadLine, "formFooter f6"))
    {
        isGoingThroughFooter := true
    }

    if(isGoingThroughJavascript)
    {
        javascript := javascript . A_LoopReadLine . "`r`n"
    }
    else if(isGoingThroughAnElement)
    {
        line := A_LoopReadLine
        if(RegExMatch(A_LoopReadLine, ".*<\/script>"))
        {
            checkForLinks(line)
        }
        element := element . line . "`r`n"
    }
    else if(isGoingThroughFooter)
    {
        footer := footer . A_LoopReadLine . "`r`n"
    }
	else
	{
        if(!RegExMatch(A_LoopReadLine, "(<link.*rel=""(?!stylesheet))|(<meta.*)|(si.*?mple.*?_spc)")) ; Skip, if the line is just a superfluous link, meta tag, or the simple_spc line that throws an error
        {
            line := A_LoopReadLine
            checkForLinks(line)
            indexTempFile.WriteLine(line)
        }
	}

    if(RegExMatch(A_LoopReadLine, ".*<\/script>", result))
    {
        result = %result% ; This is because assigning a variable in this manner removes all leading and trailing whitespace
        if(StrLen(result) <= 9)
        {
            isGoingThroughJavascript := false
        }
    }
    else if(InStr(A_LoopReadLine, "</li>"))
    {
        isGoingThroughAnElement := false
        if(RegExMatch(element, "(<li [\s\S]*?((<input)|(<select)).*id=)\K.*(name=)(?=[\s\S]*<\/li>)")) ; If it's a regular element with an input that has a name property
        {
            fixTheEntireElement(element, javascript)
        }
        else if(RegExMatch(element, "<li [\s\S]*?<img.*?src=""\K.*?(?="")")) ; If it's a shorter element with just an image in it
        {
            fixImageElement(element)
        }
        indexTempFile.write(element)
        element := ""
    }
    else if(RegExMatch(footer, "<\/div>[\s\S]*?<\/div>") && isGoingThroughFooter = 1)
    {
        isGoingThroughFooter := false
    }

    lineCounter++
    GuiControl,, ProgressBar,% lineCounter
    if(lineCounter == lineTotal)
    {
        indexTempFile.write(element)
        indexTempFile.close()
        indexTempFile := FileOpen("index.tmp", "rw")
        performFinalTouches(indexTempFile, javascript, jsByteToSeekBackTo, cssLinkByteToSeekBackTo, jsLinkByteToSeekBackTo)
    }
}
indexTempFile.close()
logText := logText . "Almost done...`r`n"
GuiControl, Text, Log, %logText%
MsgBox, 262145,, About to end. Do you want to commit the changes?
IfMsgBox Cancel
    ExitApp

if indexFile != "index.html"
{
    logText := logText . "Renaming file...`r`n"
    GuiControl, Text, Log, %logText%
    newFilePath := indexFileDir . "\index.html"
    FileMove, %indexFile%, %newFilePath%, 1
    FileDelete, indexFile
    indexFile := newFilePath
}
FileMove, index.tmp, %indexFile%, 1 ; 1 = Overrite
logText := logText . "Done!`r`n"
GuiControl, Text, Log, %logText%
ExitApp

checkForLinks(ByRef line)
{
    if(RegExMatch(line, "<link.*rel=.stylesheet"))
    {
        urlRegex := "(<link.*?(rel=.stylesheet.*href=.)\K.*(?="")|(href=.)\K.*(?="".*?rel=.stylesheet))"
        fileNameRegex := "<link.*href="".*\/\K.*?(?=\?.*"")"
        folderName := "css"
        replacementRegEx := "(<link.*?(rel=.stylesheet.*href=.)\K.*(?=\/.*"")|(href=.)\K.*(?=\/.*"".*?rel=.stylesheet))"
        replaceLink(line, urlRegex, fileNameRegex, folderName, replacementRegEx)
    }
    else if(RegExMatch(line, "(<script.*src=.*)(?=<\/script>)"))
    {
        urlRegex := "<script.*?(src=.)\K.*?(?="")"
        fileNameRegex := "<script.*src="".*\/\K.*?js(?=(\?.*)?"")"
        folderName := "js"
        replacementRegEx := "(<script.*src="")\K.*(?=\/.*js(\?.*?)?"")"
        replaceLink(line, urlRegex, fileNameRegex, folderName, replacementRegEx)
    }
}

replaceLink(ByRef line, urlRegex, fileNameRegex, folderName, replacementRegEx)
{
    logText := logText . "Replacing a file link...`r`n"
    GuiControl, Text, Log, %logText%
    RegExMatch(line, urlRegex, url)
    RegExMatch(line, fileNameRegex, fileName)
    directory := indexFileDir . "\" . folderName

    downloadFile(url, directory, fileName)
    line := RegExReplace(line, replacementRegEx, folderName)
}

fixImageElement(ByRef element)
{
    logText := logText . "Fixing an image link...`r`n"
    GuiControl, Text, Log, %logText%
    RegexMatch(element, "<img.*?src="".*\/\K.*?(?=\..*?"")", sensibleIdName)
    RegExMatch(element, "(?:<img .*src="")\K.*?(?="")", imageUrl)
    directory := indexFileDir . "\images"
    fileName :=  sensibleIdName . ".png" ; Assuming it's always a PNG may bring problems later if the image uploaded was a JPG.
    downloadFile(imageUrl, directory, fileName)
    element := RegExReplace(element, "(?:<li.*id="")\K.*?(?="")", "id_" . sensibleIdName) ; fixes the ID for the <li> tag
    element := RegExReplace(element, "(?:<img .*src="")\K.*(?=\/.*"")", "images")
    element := RegExReplace(element, "<img.*?src=.*?\K\..*(?=\.)", "")
}

fixTheEntireElement(ByRef element, ByRef javascript)
{
    logText := logText . "Fixing an element...`r`n"
    GuiControl, Text, Log, %logText%
    sensibleIdName := findTheSensibleName(element)

    javascript := fixTheJavascriptReferences(element, javascript, sensibleIdName)
    fixedElement := fixTheIds(element, sensibleIdName)
    logText := logText . "Adding custom class and GUID...`r`n"
    GuiControl, Text, Log, %logText%
    sampleClass := "SampleClass"
    fixedElement := addAClass(fixedElement, sampleClass)
    fixedElement := addTheGUIDs(fixedElement)
    element := fixedElement
}

findTheSensibleName(element)
{
    sensibleIdName := ""
    RegExMatch(element, "(?:((<input)|(<select)).*name="".*?_)\K.*?(?=(\[.*\])?"")", sensibleIdName) ; Gets the important portion of the string inside the name="" property

    return sensibleIdName
}

fixTheJavascriptReferences(element, javascript, sensibleIdName)
{
    logText := logText . "Fixing references in Javascript...`r`n"
    GuiControl, Text, Log, %logText%
    RegExMatch(element, "(?:((<input)|(<select)).*?[^gu]id="".*?)\K.*?(?="")", machineIdName)

    javascript := fixJotFormRules(machineIdName, sensibleIdName, javascript)
    javascript := fixJotFormFieldSettings(machineIdName, sensibleIdName, javascript)

    return javascript
}

fixJotFormRules(machineIdName, sensibleIdName, javascript)
{
    RegExMatch(machineIdName, ".*?_\K\d+(?=(_\d+)|\Z)", machineIdNum)
    regex := "(((""((operands)|(field)|(resultField))"":"")\K" . machineIdNum . ")|((""equation"":""){\K" . machineIdNum . ")|((""fields"":\["".*?)\K" . machineIdNum . "))(?=(""])|("",)|(}""))"
    javascript := RegExReplace(javascript, regex, sensibleIdName)

    return javascript
}

fixJotFormFieldSettings(machineIdName, sensibleIdName, javascript)
{
    while pos := RegExMatch(javascript, "(?:((set.*\()|(description\())|(\$\())(""|( )?')\K.*?(?=(""|'))", prospectiveIdMatch, A_Index = 1 ? 1 : pos+StrLen(prospectiveIdMatch))
    {
        if(InStr(machineIdName, prospectiveIdMatch))
        {
            fixedId :=
            if(RegExMatch(javascript, "(setCalendar\()(""|( )?')\K" . prospectiveIdMatch . "(?=(""|'))"))
            {
                fixedId := sensibleIdName
            }
            else
            {
                fixedId := "input_" . sensibleIdName
            }
            javascript := RegExReplace(javascript, "(?:(((set.*\()|(description\()))|(\$\())(""|( )?')\K" . prospectiveIdMatch . "(?=(""|'))", fixedId)
        }
    }

    return javascript
}

fixTheIds(element, sensibleIdName)
{
    logText := logText . "Replacing IDs...`r`n"
    GuiControl, Text, Log, %logText%
    element := RegExReplace(element, "(?:<li.*id="")\K.*?(?="")", "id_" . sensibleIdName) ; fixes the ID for the <li> tag
    if(InStr(element, "<input")||InStr(element, "<select"))
    {
        element := RegExReplace(element, "((((<input)|(<select)).*id="".*?_([a-zA-Z]*_)?)\K\d*)|((<label.*for="".*?_([a-zA-Z]*_)?)\K\d*)", sensibleIdName) ; fixes the ID for the <input> or <select> tags, as well as any for="" properties in the labels that are set to them
    }
    if(InStr(element, "<label"))
    {
        labelledElement :=
        Loop, Parse, element, `n, `r
        {
            if(RegExMatch(A_LoopField, "(<label.*for=.*id=).*|(<label.*id=.*for=).*"))
            {
                baseForNewId := ""
                currentId := ""

                RegExMatch(A_LoopField, "(?:<label.*id="")\K.*?(?="")", currentId) ; Fetches the current ID from its field
                RegExMatch(A_LoopField, "(?:<label.*for="")\K.*?(?="")", baseForNewId) ; Fetches the name from the for= field to base its own ID off of
                idStart := SubStr(currentId, 1, InStr(currentId, "_"))
                fixedLine := StrReplace(A_LoopField, "id=""" . currentId . """", "id=""" . idStart . baseForNewId . """")

                labelledElement := labelledElement . fixedLine . "`r`n"
                baseForNewId := ""
                currentId := ""
                fixedLine := ""
            }
            else if(RegExMatch(A_LoopField, "labelledby.*", match))
            {
                RegExMatch(A_LoopField, "id=.\K.*?(?="")", id)
                replacedMatch := RegExReplace(match, "\d+.*?(?=( s)|"")", id)
                fixedLine := StrReplace(A_LoopField, match, replacedMatch)
                labelledElement := labelledElement . fixedLine . "`r`n"
            }
            else
            {
                labelledElement := labelledElement . A_LoopField . "`r`n"
            }
        }
        element := labelledElement
    }
    if(InStr(element, "<div id=""cid"))
    {
        element := RegExReplace(element, "<div id=.\K.*?(?="")", "cid_" . sensibleIdName)
    }
    if(InStr(element, "<img"))
    {
        element := RegExReplace(element, "(?:<img .*id="".*?)\K.*_.*(?=_.*"")", "input_" . sensibleIdName)
        element := RegExReplace(element, "(?:<img .*src="")\K.*(?=\/.*"")", "images")
    }
	return element
}

addAClass(element, classToAdd)
{
    if(RegExMatch(element, "(?:((<input)|(<select)).*?class="".*?)\K" . classToAdd . "(?="")"))
    {
        return element ;It already has the class, so you can just return the element as is
    }
    element := RegExReplace(element, "(?:((<input)|(<select)).*?class="".*?)\K""", " " . classToAdd . """")
    return element
}

addTheGUIDs(element)
{
    if(!RegExMatch(element, "(?:((<input)|(<select)).*?)\Kguid"))
    {
        element := RegExReplace(element, "(?:((<input)|(<select)).*?)\K(\/)?>", "guid=""""/>")
    }

    Loop, Parse, element, `n, `r
    {
        if(InStr(A_LoopField, "guid"))
        {
            fixedLine := RegExReplace(A_LoopField, "(?:((<input)|(<select)).*?guid="")\K.*?(?="")", getARandomGUID()) ; Fills, or replaces the GUID field
            element := StrReplace(element, A_LoopField, fixedLine)
            fixedLine := ""
        }
    }
    return element
}

getARandomGUID()
{
    global numOfGUIDs
    global bannedNumbersList
    randomLineNum := 0
    Loop
    {
        Random, randomLineNum, 1, numOfGUIDs
    } Until !isValueInArray(randomLineNum, bannedNumbersList)
    bannedNumbersList.push(randomLineNum)
    line := ""
    FileReadLine, line, guidList.txt, randomLineNum
    return line
}

isValueInArray(value, arrayToLookAt)
{
    for arrValue in arrayToLookAt
        if(value = arrValue)
        {
            return true
        }
    return false
}

performFinalTouches(indexTempFile, javascript, jsByteToSeekBackTo, cssLinkByteToSeekBackTo, jsLinkByteToSeekBackTo)
{
    logText := logText . "Giving its final touches...`r`n"
    GuiControl, Text, Log, %logText%
    appendTextToFile(indexTempFile, jsByteToSeekBackTo, javascript) ; Appends the fixed javascript
}

appendTextToFile(ByRef file, byteToSeekBackTo, textToAppend)
{
    file.Seek(byteToSeekBackTo)
    restOfTheText := file.Read()
    file.Seek(byteToSeekBackTo)
    file.WriteLine(textToAppend)
    file.Write(restOfTheText)
}

downloadFile(url, directory, fileName)
{
    logText := logText . "Attempting to download " . fileName . "...`r`n"
    GuiControl, Text, Log, %logText%
    if(!InStr(url, "https:"))
    {
        url := "https:" . url
    }
    if(!InStr(FileExist(directory), "D"))
    {
        FileCreateDir, %directory%
    }

    fullDirectory := directory . "\" . fileName
    if(FileExist(fullDirectory))
    {
        ; Already downloaded. You can skip it.
        logText := logText . "The file " . fileName . " already exists. Skipping...`r`n"
        GuiControl, Text, Log, %logText%
        return
    }

    RegExMatch(url, "https:\/\/\K.*?(?=\/)", baseUrl)
    RunWait, ping.exe %baseUrl% -n 1,, Hide UseErrorLevel
    if(ErrorLevel)
    {
        ; Can't reach the url. Connection is likely down
        logText := logText . "Can't reach the link " . url . " for " . fileName . ". You will have to download it manually. It's possible your connection is down`r`n"
        GuiControl, Text, Log, %logText%
        return
    }

    try UrlDownloadToFile, %url%, %fullDirectory%
    catch e
    {
        logText := logText . "Failed to download the file`r`nUrl: " . url . "`r`nDirectory: " . directory . "`r`nFile name: " . fileName . "`r`nFull directory: " . fullDirectory . "`r`n"
        GuiControl, Text, Log, %logText%
        MsgBox Failed to download the file`nUrl: %url%`nDirectory: %directory%`nFile name: %fileName%`nFull directory: %fullDirectory%
    }
}

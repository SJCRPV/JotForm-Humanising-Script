# JotForm-Humanising-Script

This is merely a script that I developed during work to make JotForms more amicable for the people who use it.
It makes all inputs have more readable variables names, it downloads all Javascript and CSS files to a local folders, backups the original file, can add in custom classes, uniquely identifies every input and logs the entire process so you know what went on.

## Instructions
This requires you to have AutoHotKey installed.

JotForm-wise, there is one very important thing to do:
In the platform, while making the form, every element that you want to have more human-readable names needs to have its "name" property set with the name you'd like it to have, since that's the basis of everything.

After compilation, all that is necessary is that you have the "guidList.txt" file in the same directory. Executing it will ask you to identify the "HTML" file that you want parsed. That is all that is necessary on your end. The rest will happen automatically.

## Known issue
If you are using calendar elements, the "jotform.forms.js" file requires a simple fix.
The file expects you to have an ID in the input field composed of numbers. You will have to find the function that checks for that and replace the regex `[0-9]` with just `.`

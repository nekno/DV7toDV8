#!/usr/bin/env osascript

on run argv
    displayLanguageDialog()
end run

on displayLanguageDialog()
    set lang to ""
    set dialogText to "Enter the audio and subtitle languages you would like included in the final output.\n\nYou can provide a comma-separated list of language codes or delete all text and leave the textbox empty to include all languages.\n\nYou can provide ISO 639-1 codes (\"en,es,de\") or ISO 639-2 codes (\"eng,spa,ger\").\n\nClick the Help button for a list of language codes."
    set helpButton to "Help"
    set okButton to "OK"

    try
        set lang to characters 1 thru 2 of user locale of (get system info) as string
    end try

    display dialog dialogText default answer lang buttons {helpButton, okButton} default button okButton with title "Enter Languages"
    
    if button returned of result is helpButton then
        open location "https://www.loc.gov/standards/iso639-2/php/English_list.php"
        displayLanguageDialog()
    else
        return text returned of result
    end if
end displayLanguageDialog
{$mode objfpc}{$H+}
unit CGEStrings;

{ Centralised user-visible strings for the CGE views.

  All strings shown to the user should be declared here as FPC
  resourcestrings.  Compiling emits a .rsj file that `rstconv` turns
  into a .pot/.po file for translation with Crowdin.

  Regenerate the .pot with scripts/extract-pot.sh.

  Conventions:
    Prefix groups by screen/area:
      rsCommon*   — buttons & chrome shared across views
      rsHome*     — home screen
      rsLogin*    — user-profile / login flow
      rsTerms*    — terms of use
      rsSettings* — settings view
      rsNewProj*  — new project wizard
      rsImport*   — import flow
      rsEditor*   — project editor + read mode
      rsFeedback* — feedback dialog
      rsStatus*   — status-bar messages
}

interface

resourcestring
  { ── Common / chrome ───────────────────────────────────────────────── }
  rsAppName             = 'BTT-Writer';
  rsAppSubtitle         = 'Bible Translation Tool';
  rsCommonOK            = 'OK';
  rsCommonCancel        = 'CANCEL';
  rsCommonBack          = 'Back';
  rsCommonSave          = 'Save';
  rsCommonClose         = 'Close';
  rsCommonContinue      = 'Continue';
  rsCommonSend          = 'SEND';
  rsCommonYes           = 'Yes';
  rsCommonNo            = 'No';
  rsCommonSearch        = 'Search';
  rsCommonUser          = 'Current User: %s  (Logout)';

  rsStatusIdle          = 'Idle';
  rsStatusLoading       = 'Loading…';
  rsStatusLoggingIn     = 'Logging in…';
  rsStatusSearching     = 'Searching…';
  rsStatusImporting     = 'Importing…';
  rsStatusExporting     = 'Exporting…';
  rsStatusUploading     = 'Uploading…';

  { ── Home screen ───────────────────────────────────────────────────── }
  rsHomeCrumb           = 'Your Translation Projects';
  rsHomeWelcomeTitle    = 'Welcome!';
  rsHomeWelcomeBody     =
    'This is your Home Screen. When you have translation' + sLineBreak +
    'projects on this device, they will appear here.' + sLineBreak + sLineBreak +
    'You can start a new project anytime by tapping the' + sLineBreak +
    'green button in the top right.';
  rsHomeStartProject    = 'START A NEW PROJECT';
  rsHomeNewProject      = '+ New Project';
  rsHomeOpen            = 'Open';
  rsHomeLogoutConfirm   = 'Log out of BTT-Writer?';

  rsMenuUpdate          = 'Update';
  rsMenuImport          = 'Import …';
  rsMenuAcademy         = 'translationAcademy';
  rsMenuFeedback        = 'Feedback';
  rsMenuLogout          = 'Logout';
  rsMenuSettings        = 'Settings';

  { ── Login / user profile ──────────────────────────────────────────── }
  rsLoginCrumb              = 'User Profile';
  rsLoginLocalCrumb         = 'Local Profile';
  rsLoginServerCrumb        = 'Server Login';
  rsLoginChooserTitle       = 'Setup your User Profile with one of the options below.';
  rsLoginOptServerTitle     = 'Login to your Server Account';
  rsLoginOptServerDesc      = 'Use this option to be able to upload projects to your existing account';
  rsLoginOptCreateServerTitle = 'Create a Server Account';
  rsLoginOptCreateServerDesc  = 'Use this option if you do not have an account but want to upload';
  rsLoginOptLocalTitle      = 'Create Local User Profile';
  rsLoginOptLocalDesc       = 'Use this option if you do not have an account and do not want to upload';

  rsLoginLocalHeading       = 'Local User Profile';
  rsLoginLocalDesc          =
    'Enter your full name or pseudonym. This name will be added to' + sLineBreak +
    'the contributor list of all projects you work on. This name will be' + sLineBreak +
    'visible to others.';
  rsLoginLocalPlaceholder   = 'Full Name or Pseudonym';
  rsLoginLocalError         = 'Please enter a name.';
  rsLoginLocalSubmit        = 'OK';
  rsLoginLocalToServer      = 'LOGIN WITH SERVER ACCOUNT';

  rsLoginServerHeading      = 'Server Login';
  rsLoginServerNetWarning   = 'This will use your internet connection';
  rsLoginServerURL          = 'Server URL';
  rsLoginServerUser         = 'Username';
  rsLoginServerPass         = 'Password';
  rsLoginServerSubmit       = 'LOGIN';
  rsLoginServerCreate       = 'CREATE A NEW ACCOUNT';
  rsLoginServerNeedURL      = 'Please enter a server URL.';
  rsLoginServerNeedUser     = 'Please enter a username.';
  rsLoginServerFailed       = 'Login failed: %s';

  { ── Terms of Use ──────────────────────────────────────────────────── }
  rsTermsCrumb              = 'Terms of Use';
  rsTermsIntro              =
    'By using this app you agree with the statement of faith and translation guidelines' + sLineBreak +
    'and to release your work under the terms of the Creative Commons' + sLineBreak +
    'Attribution-ShareAlike 4.0 International License.';
  rsTermsLicenseAgreement   = 'License Agreement';
  rsTermsTranslationGuide   = 'Translation Guidelines';
  rsTermsStatementOfFaith   = 'Statement of Faith';
  rsTermsNoThanks           = 'NO THANKS';
  rsTermsAgree              = 'I AGREE';

  { ── Settings ──────────────────────────────────────────────────────── }
  rsSettingsCrumb           = 'Settings';
  rsSettingsSectionGeneral  = 'General';
  rsSettingsSectionAbout    = 'About';
  rsSettingsSectionLegal    = 'Legal';
  rsSettingsSectionAdvanced = 'Advanced';
  rsSettingsTheme           = 'Theme';
  rsSettingsThemeLight      = 'Light';
  rsSettingsThemeDark       = 'Dark';
  rsSettingsThemeSystem     = 'System';
  rsSettingsThemeCurrent    = 'Current: %s';
  rsSettingsVersion         = 'Version: %s';
  rsSettingsDataPath        = 'Data: %s';

  { ── New Project ───────────────────────────────────────────────────── }
  rsNewProjCrumbHome        = 'Home';
  rsNewProjCrumbSourceTexts = 'Source Texts';
  rsNewProjCrumbByLanguage  = 'By Language';
  rsNewProjChooseLanguage   = 'Choose a language';
  rsNewProjChooseCategory   = 'Choose a category';
  rsNewProjChooseSources    = 'Choose Source(s)';
  rsNewProjOldTestament     = 'Old Testament';
  rsNewProjNewTestament     = 'New Testament';
  rsNewProjOther            = 'Other';
  rsNewProjSelectAll        = 'Select All';
  rsNewProjUnselectAll      = 'Unselect All';
  rsNewProjDownload         = 'DOWNLOAD';

  { ── Import ────────────────────────────────────────────────────────── }
  rsImportCrumb             = 'Import';
  rsImportOptions           = 'Import Options';
  rsImportFromServer        = 'Import from Server';
  rsImportProjectFile       = 'Import Project File';
  rsImportUSFMFile          = 'Import USFM File';
  rsImportSourceText        = 'Import Source Text';
  rsImportPathPrompt        = 'Enter the full path to the .tstudio file:';
  rsImportPathPlaceholder   = '/path/to/file.tstudio';
  rsImportUSFMPathPrompt    = 'Enter the full path to the .usfm file:';
  rsImportUSFMPathPlaceholder = '/path/to/file.usfm';
  rsImportUSFMLangPrompt    = 'Target language code (e.g. fr, ru, id):';
  rsImportLangPlaceholder   = 'Language code';
  rsImportButton            = 'Import';
  rsImportNeedFilePath      = 'Please enter the path to the .tstudio file.';
  rsImportNeedUSFMPath      = 'Please enter the path to the .usfm file.';
  rsImportNeedLangCode      = 'Please enter a target language code.';
  rsImportFileNotFound      = 'File not found: %s';
  rsImportImported          = 'Imported: %s';
  rsImportMergedConflicts   = 'Merged with conflicts: %s. Open the project to resolve.';
  rsImportSearchUser        = 'Username';
  rsImportSearchBook        = 'Book or Language';
  rsImportSearchNeed        = 'Enter a username or book/language code.';
  rsImportSearchNoResults   = 'No repositories found.';
  rsImportSearchResultsFmt  = '%d result(s)';
  rsImportDupPrompt         =
    'A project with this name already exists.' + sLineBreak +
    'How would you like to proceed?';
  rsImportDupMerge          = 'Merge';
  rsImportDupOverwrite      = 'Overwrite';
  rsImportSourceStub        =
    'Source texts are managed through the New Project flow.' + sLineBreak + sLineBreak +
    'Return to Home and use "+ New Project" to add a source text.';

  { ── Editor ────────────────────────────────────────────────────────── }
  rsEditorReadMode          = 'Read';
  rsEditorBlindEdit         = 'Blind Edit';
  rsEditorShowSource        = 'Show Source';
  rsEditorHideSource        = 'Hide Source';
  rsEditorMarkChunkDone     = 'Mark chunk as done';
  rsEditorEdit              = 'Edit';
  rsEditorChapterOfFmt      = 'Chapter %s of %d';

  rsMenuMarkChapterDone     = 'Mark Chapter Done';
  rsMenuUploadToServer      = 'Upload to Server';
  rsMenuExportTStudio       = 'Export .tstudio';
  rsMenuExportUSFM          = 'Export USFM';

  rsEditorReadNoTranslation = 'No translation yet for this chapter.';
  rsEditorReadNoSource      = 'Source text not available.';
  rsEditorShowTranslation   = 'Show Translation';

  rsExportUploadDone        = 'Uploaded: %s';
  rsExportUploadNoServer    = 'Upload requires a server account. Please log in with a server profile.';
  rsExportUploadCommitFail  = 'Commit failed: %s';
  rsExportUploadRepoFail    = 'Could not create repo: %s';
  rsExportUploadRemoteFail  = 'Could not set remote: %s';
  rsExportUploadPushFail    = 'Push failed: %s';
  rsExportTStudioSaved      = 'Saved: %s';
  rsExportUSFMSaved         = 'Saved: %s';
  rsExportFailed            = 'Export failed: %s';

  { ── Feedback ──────────────────────────────────────────────────────── }
  rsFeedbackCrumb           = 'Feedback';
  rsFeedbackHeading         = 'Feedback';
  rsFeedbackNetWarning      = 'This will use your internet connection';
  rsFeedbackPrompt          = 'Describe the problem you are experiencing:';
  rsFeedbackPlaceholder     = 'Enter your feedback here…';
  rsFeedbackSend            = 'SEND';
  rsFeedbackCancel          = 'CANCEL';
  rsFeedbackEmpty           = 'Please enter a message before sending.';
  rsFeedbackSent            = 'Thank you! Your feedback has been recorded.';

implementation

end.

# BTT-Writer version two project

## Goal
We will make a software project with Free Pascal and Lazarus that will be backward-compatible with BTT-Writer Desktop (and hopefully Android).

This project will be compiled for Linux, Windows, and macOS, and Android if possible.

Development is on Linux.

An additional directory that will need to be examined is ~/.config/BTT-Writer. We will call this the DATA PATH.

## Criteria
BTT-Writer is a Bible translation program that encourages the use of an eight step process for translation.

Step 3 of the process is called "Chunking", when the text is broken up into chunks to facilitate translation. Unfortunately, legacy software skipped this step by pre-chunking the text. Additionally, different source texts used different chunking strategies, so different projects end up with different numbers of chunks. Finally, the whole thing was written in Electron/NodeJS and suffers the normal performance and disk space problems of that platform.

The new program will use English ULB chunks for file storage, to maintain backwards compatibility with existing tooling. However, when a project is loaded, the chunks will be streamed into a single text in memory or temporary storage. Then, it will split the project on-screen based upon the chunking in the source text being used. This opens the possibility of allowing the user to chunk the text at some future date.

### Source Texts
The source texts are stored in DATA PATH/library/resource_containers. Most sources are for one Bible book. The source text for Acts in the English Unlocked Literal Bible is stored in a directory called `en_act_ulb`.

Bible source texts are stored in `.usx` format. Inside the directory, there is a content directory containing the .usx files, a LICENSE.md file, and a package.json file. Inside the content directory are directories numbered 01 … n, for each of the chapters in the book. (i.e. for Acts it is 01 … 28.) There is also a "front" directory which contains `title.usx`, the name of the book. Also in the content directory are a config.yml and toc.yml file.

toc.yml gives a structure for the chunking of the book. config.yml lists the important words in each chunk, pointing to the location in a translationWords source.

When BTT-Writer is initially launched, the resource_containers folder will be empty (or just created). The English translationWords for the ULB Bible is installed immediately, but other source folders are installed as needed by projects. These sources are stored in a compressed archive in the program directory until needed.

### Project files
Project files are stored in DATA PATH/targetTranslations. The projects are in directories named like en_act_text_ulb (for a project intended to be a source text) or en_act_text_reg (if this is a translation intended to be consumed by mother-tongue speakers). There is a LICENSE.md file that explains the creative commons license, and a manifest.json file that contains information about the book (usfm code for the book, list of contributors, which source is used, "closed" chunks.) In the same folder are folders for each of the chapters, and one called "front" for the book name. The project is also a git repository, so contains a .git folder.

## Behavior
Each chunk can be opened for editing, closed from editing, and "marked finished", meaning that all translation steps have been performed for that chunk. When the chunk is open for editing, the program should display a simple text editing window. When the chunk is closed from editing or marked finished, the program should display a read-only box that contains the text, possibly with some formatting. When the chunk is marked finished, it should disable the ability to enter editing mode unless the chunk un un-marked finished first. Also, marking a chunk finished or unfinished should update the manifest.json with that information. The chunk should be written to disk when editing is disabled, when the editor loses focus, or after five minutes, whichever happens first. The chunks should be written to disk in the chunks of the English ULB, regardless of the chunks used for the current project. Thus, if the Russian source (say) has a chunk for verses 1-5, but the English has one chunk for 1-3 and another chunk for 4-5, the program should write verses 1-3 in the appropriate chunk file, and verses 4-5 in a different appropriate file, even though they are displayed as one chunk in the program. Chunk files are plain text files with a .txt extension, and they contain USFM styled text. They are named 01.txt, 04.txt (as in the preceding example) based upon the first verse of the chunk. (This is the same system as is used for the source .usx files.) 

During the editing or proofing steps of translation, an additional pane should be available to the right (or left if working with right-to-left scripts) showing the words, questions, and notes appropriate to the verses being edited.

When the chunk is being edited, verse markers are displayed using their USFM text, i.e. \v 1 for verse one. When the chunk is closed to editing, but not marked finished, the verse marker is displayed as a colored "baloon" containing the number. This baloon can be moved by the user within the chunk, and the program will insert or move the verse marker to before the hilighted word.
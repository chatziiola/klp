;;; klp.el --- Chasing simplicity -*- lexical-binding: t -*-

;; This file has been generated from the literate.org file. DO NOT EDIT.
;; Sources are available from https://github.com/chatziiola/klp

;; Copyright (C) 2022-2023 Lamprinos Chatziioannou

;; Author: Lamprinos Chatziioannou
;; Maintainer: Lamprinos Chatziioannou 
;; URL: https://github.com/chatziiola/klp

;; Special thanks to Jethro Kuan (https://github.com/jethrokuan) for inspiring
;; me to tailor my set up to my needs, and to David Wilson
;; (https://github.com/daviwil) and Nicolas P. Rougier
;; (https://github.com/rougier), for inspiring me to give back to the amazing
;; Emacs, Org, and FOSS comunities.

;; This file is NOT part of GNU Emacs.

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This file is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; This small package is to help you keep a clean and organized directory
;; structure, easily find your notes and bootstrap the note-creation process.

;; To achieve this functionality, the package utilizes two basic /rules/:
;;;1. A file-naming standard: notes_(category_)title.org
;;;; You, obviously, can tailor that to your needs, but I haven't had, so far a
;;;; single reason to do so. Its structure allows for note files to be grouped
;;;; up together when navigating the notes-directory manually.
;;;2. A file-properties standard: #+<PROPERTY>: <VALUE>
;;;; This can also be modified, even though it is tricky and (as a tip), should
;;;; be done gradually and not at once. Just because a feature exists it does
;;;; not mean that it should be used

;; For a deep dive into the ideology of the package, look up the README.org file
;; that you should have received along with it.

;;; Code:

(require 'org)

(defvar klp/static-notes-dir "~/org/notes"
  "The default directory in which static notes will be stored.")

(defvar klp/default-keyword-alist (list "TITLE" "DATE")
  "The default set of parameters to be entered upon note creation.")

;;;### autoload
(defun klp/sluggify (inputString)
  "Given a string return it's /sluggified/ version.
It has only one argument, INPUTSTRING, which is self-described"
  (let ((slug-trim-chars '(
			   ;; Combining Diacritical Marks https://www.unicode.org/charts/PDF/U0300.pdf
                           768 ; U+0300 COMBINING GRAVE ACCENT
                           769 ; U+0301 COMBINING ACUTE ACCENT
                           770 ; U+0302 COMBINING CIRCUMFLEX ACCENT
                           771 ; U+0303 COMBINING TILDE
                           772 ; U+0304 COMBINING MACRON
                           774 ; U+0306 COMBINING BREVE
                           775 ; U+0307 COMBINING DOT ABOVE
                           776 ; U+0308 COMBINING DIAERESIS
                           777 ; U+0309 COMBINING HOOK ABOVE
                           778 ; U+030A COMBINING RING ABOVE
                           779 ; U+030B COMBINING DOUBLE ACUTE ACCENT
                           780 ; U+030C COMBINING CARON
                           795 ; U+031B COMBINING HORN
                           803 ; U+0323 COMBINING DOT BELOW
                           804 ; U+0324 COMBINING DIAERESIS BELOW
                           805 ; U+0325 COMBINING RING BELOW
                           807 ; U+0327 COMBINING CEDILLA
                           813 ; U+032D COMBINING CIRCUMFLEX ACCENT BELOW
                           814 ; U+032E COMBINING BREVE BELOW
                           816 ; U+0330 COMBINING TILDE BELOW
                           817 ; U+0331 COMBINING MACRON BELOW
                           )))
    (cl-flet* ((nonspacing-mark-p (char) (memq char slug-trim-chars))
               (strip-nonspacing-marks (s) (ucs-normalize-NFC-string
                                            (apply #'string
                                                   (seq-remove #'nonspacing-mark-p (ucs-normalize-NFD-string s)))))
               (cl-replace (inputString pair) (replace-regexp-in-string (car pair) (cdr pair) inputString)))
      (let* ((pairs `(("[^[:alnum:][:digit:]]" . "_") ;; convert anything not alphanumeric
                      ("__*" . "_")                   ;; remove sequential underscores
                      ("^_" . "")                     ;; remove starting underscore
                      ("_$" . "")))                   ;; remove ending underscore
             (slug (-reduce-from #'cl-replace (strip-nonspacing-marks inputString) pairs)))
        (downcase slug)))))

(defun ndk/get-keyword-key-value (kwd)
  "Only to be used by `klp/get-keyword-value'.

Allows for the extraction of KWD from the current buffer.
Works only for buffers using the Org-Mode syntax."
  (let ((data (cadr kwd)))
    (list (plist-get data :key)
          (plist-get data :value))))

(defun klp/get-keyword-value (key &optional file)
  "Return the value with KEY in the current org buffer.

More specifically, in the following example, 'Gilbert Strang'
would be what's returned:

File contents:
    ...
    #+Professor: Gilbert Strang
    ...

Command:
    (klp/get-keyword-value \"Professor\")

If FILE argument is given, then instead of searching inside the
current buffer, file is opened and the function is run there.

May also be used with a list of keys in a recursive manner."
  ;; TODO: THAT FILE CHECK SHOULD MOST PROBABLY BE BETTER
  (let ((file (or file buffer-file-name)))
    (if (not (string-blank-p file))
        (with-current-buffer (find-file-noselect file)	;;Anyway: visit that file
          (let ((temp-map				;; This is to avoid multiple calls of the same function - they are unecessary
		 (org-element-map
		     (org-element-parse-buffer 'greater-element)
		     '(keyword) #'ndk/get-keyword-key-value)))
            (cond
                ((proper-list-p key)			;; If the KEY element is a list
                 (let ((keyVals '()))
		   (cl-loop for title in key do
			    (add-to-list 'keyVals (nth 1 (assoc title temp-map)) t))
		   keyVals))

                (t					;; Else it must be a single element
                    (nth 1 (assoc key temp-map)))))))))

(defun klp/get-note-files-list (&optional category)
  "Get a list of all the filenames of notes files.

If the optional (string) argument CATEGORY is given, limit the
filenames to the ones in category CATEGORY"
  (let ((category (or category "")))
  (directory-files klp/static-notes-dir 'full
		   (concat "notes" (unless (string-blank-p category)
				     (concat "_" category)) "_.*\.org")))
  )

(defun klp/get-keyword-alist-text (keyword-alist title)
  "Parser for KEYWORD-ALIST.

Given a KEYWORD-ALIST it returns a string, In the proper format
for insertion in the newly created `org-mode` file.

Special members of KEYWORD-ALIST are the keywords TITLE and DATE,
because TITLE is populated through the prompt-answer
variable (see `klp/open-note')"
    (concat
     "#+TITLE:" title
     "\n#+DATE: " (format-time-string "<%Y-%m-%d>")
     
     )
  )

(defun klp/get-new-note-filename (title &optional category)
  "Return a string with the filename for the new note.

The standard format, as described in documentation is:
`notes(_category)_title.org`.
- The TITLE field is sluggified to ensure readability and consistency
- The CATEGORY field is omitted if empty."
 (let ((category (or category "")))
   (expand-file-name
    (concat "notes_"
	    (unless (string-blank-p category)
	      (concat category "_"))
	    (klp/sluggify title) ".org")
    klp/static-notes-dir)))

(defun klp/create-notes-prompt-list (filelist keyword-alist)
  "Create the prompt list.

FILELIST is self-descriptive in the context.
KEYWORD-ALIST, the same.

Called by`klp/open-note'.

I wrote this as an independent function for utilization in the
future."
  (seq-map (lambda (filename)
	     (list (format "%-40s %-50s" ;; FIXME make this use a different parser as well
			   (klp/get-keyword-value keyword-alist filename)
			   filename)
		   filename))
	   filelist)
  )

(defun klp/open-note (&optional category keyword-alist)
  "Find or Create new note function to make everything smoother and cooler.
If the optional arguments CATEGORY and KEYWORD-ALIST are given:

TODO Fix docstring
CATEGORY: Will limit the search in the category area, and if a
new note is to be created it will be of that category.

KEYWORD-ALIST: This is the default set of parameters to be
entered upon the creation of a new note. Defaults to
`klp/default-keyword-alist'."
  (interactive)
  (let* ((category (or category ""))
	 (keyword-alist (or keyword-alist klp/default-keyword-alist))
         (prompt-list (klp/create-notes-prompt-list
		       (klp/get-note-files-list category) keyword-alist))
         (prompt-answer
                (completing-read (concat "Select " category ": ") prompt-list)))
        (cond
	; 'it' in the following comments stands for the answer, usually the
	; topic on which you want to write a note
         ((not (assoc prompt-answer prompt-list))       ; it does not exist in the list
	  (org-open-file				; open the org file
	   (klp/get-new-note-filename prompt-answer category))
	  (insert					; insert the parameters specified in keyword alist
	   (klp/get-keyword-alist-text keyword-alist prompt-answer)))
	 (t						; else (if it exists)
	  (org-open-file				; Open the associated to the answer file
	   (nth 1 (assoc prompt-answer prompt-list))))
        )
    )
)

(provide 'klp)
;;; klp.el ends here

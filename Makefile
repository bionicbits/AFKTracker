# Makefile for packaging WoW addon without macOS hidden files

ADDON_NAME = AFKTracker
ZIP_FILE = $(ADDON_NAME).zip

package:
	rm -f $(ZIP_FILE)
	cd src && zip -r ../$(ZIP_FILE) $(ADDON_NAME) -x "*/.*" -x "*/__MACOSX/*"

clean:
	rm -f $(ZIP_FILE)

.PHONY: package clean

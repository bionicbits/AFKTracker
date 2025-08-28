# Makefile for packaging WoW addon without macOS hidden files

ADDON_NAME = AFKTracker
ZIP_FILE = $(ADDON_NAME).zip

clean-hidden:
	find src/$(ADDON_NAME) -name '__MACOSX' -exec rm -rf {} \;
	find src/$(ADDON_NAME) -name '._*' -delete
	find src/$(ADDON_NAME) -name '.DS_Store' -delete

package: clean-hidden
	rm -f $(ZIP_FILE)
	cd src && zip -r -X ../$(ZIP_FILE) $(ADDON_NAME) -x '*.DS_Store' -x '*/.DS_Store' -x '__MACOSX/*' -x '*/__MACOSX/*' -x '._*' -x '*/._*'

clean:
	rm -f $(ZIP_FILE)

.PHONY: package clean clean-hidden

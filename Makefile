# Makefile for packaging WoW addon without macOS hidden files

ADDON_NAME = AFKTracker
# Extract version from TOC file  
VERSION := $(shell grep Version src/$(ADDON_NAME)/$(ADDON_NAME).toc | awk '{print $$3}')
ZIP_FILE = $(ADDON_NAME)-$(VERSION).zip

clean-hidden:
	find src/$(ADDON_NAME) -name '__MACOSX' -exec rm -rf {} \;
	find src/$(ADDON_NAME) -name '._*' -delete
	find src/$(ADDON_NAME) -name '.DS_Store' -delete

package: clean-hidden
	@echo "Building $(ZIP_FILE) from version $(VERSION)"
	rm -f $(ADDON_NAME)*.zip
	cd src && zip -r -X ../$(ZIP_FILE) $(ADDON_NAME) -x '*.DS_Store' -x '*/.DS_Store' -x '__MACOSX/*' -x '*/__MACOSX/*' -x '._*' -x '*/._*'
	@echo "Package created: $(ZIP_FILE)"

clean:
	rm -f $(ADDON_NAME)*.zip

.PHONY: package clean clean-hidden

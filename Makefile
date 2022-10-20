format:
	swift-format \
		--ignore-unparsable-files \
		--in-place \
		--recursive \
		./Examples ./Sources/ ./Tests Package.swift

.PHONY: format

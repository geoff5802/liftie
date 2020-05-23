PROJECT=liftie

NODE_BIN=./node_modules/.bin
BUILD_DIR=public/scripts
CSS_DIR=public/stylesheets
SRC = $(wildcard lib/client/*/*.js)
LINT_SRC = app.js bin/generate lib test

PLUGINS = lifts twitter weather webcams snow

all: lint test build

# common rules

%.br: %
	brotli --best --force $<

%.gz: %
	gzip --best --force --keep $<

%.min.js: %.js
	$(NODE_BIN)/terser \
		--compress "pure_funcs=console.log" \
		--mangle \
		--comments false \
		--output $@ \
		--ecma 2016 \
		$<

%.css: %.styl
	$(NODE_BIN)/stylus $<
	$(NODE_BIN)/postcss \
		--use postcss-cachify \
		--postcss-cachify.baseUrl /stylesheets \
		--postcss-cachify.basePath public \
		--use autoprefixer \
		--output $@ $@

%.min.css: %.css
	$(NODE_BIN)/cleancss --skip-rebase -O1 --output $@ $<

%.js: %.debug.js
	$(NODE_BIN)/exorcist \
		--error-on-missing \
		--base $(abspath $(CURDIR)/..) \
		--root / \
		--url /scripts/$(@F).map \
		$@.map < $< > $@

lint:
	$(NODE_BIN)/jshint $(LINT_SRC)

test:
	$(NODE_BIN)/mocha --recursive --require should --require test/replay

$(BUILD_DIR):
	mkdir -p $@

$(BUILD_DIR)/$(PROJECT).debug.js: $(SRC) node_modules | $(BUILD_DIR)
	NODE_PATH=lib/client:node_modules \
	$(NODE_BIN)/browserify \
		--debug \
		--plugin ./node_modules/bundle-collapser/plugin \
		--plugin ./node_modules/common-shakeify \
		--require resort/lifts \
		--require resort/twitter \
		--require resort/weather \
		--require resort/webcams \
		--require resort/snow \
		--entry lib/client/boot/index.js \
		--outfile $@

$(BUILD_DIR)/$(PROJECT)-embed.js: lib/embed/index.js | $(BUILD_DIR)
	echo '(function(){' > $@
	cat $< >> $@
	echo '}());' >> $@

# stylus for CSS

$(CSS_DIR)/style.css: $(wildcard $(CSS_DIR)/*.styl)

build: $(BUILD_DIR)/$(PROJECT).js $(CSS_DIR)/style.css $(BUILD_DIR)/$(PROJECT)-embed.js

# minized and compressed version for deployment
DIST = $(BUILD_DIR)/$(PROJECT).min.js $(CSS_DIR)/style.min.css $(BUILD_DIR)/$(PROJECT)-embed.min.js

.PRECIOUS: $(DIST)
dist: $(DIST:%=%.gz)
dist: $(DIST:%=%.br)

# cleaning

clean:
	rm -rf $(BUILD_DIR) $(CSS_DIR)/style.css* $(CSS_DIR)/style.min.css*

distclean: clean
distclean:
	rm -rf node_modules

.PHONY: all test build dist clean distclean

MOCHA_OPTS=
REPORTER = dot

test:
	@NODE_ENV=test ./node_modules/mocha/bin/mocha \
		--reporter $(REPORTER) \
		--compilers coffee:coffee-script \
		$(MOCHA_OPTS)

test-cov: lib-cov
	@OSC_COV=1 $(MAKE) test REPORTER=html-cov > coverage.html

build:
	rm -rf lib/*
	coffee -c -o lib/ src/

clean:
	rm -rf lib/*
	rm -rf lib-cov

lib-cov: clean build
	@jscoverage lib lib-cov

.PHONY: test

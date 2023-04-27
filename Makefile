
clean:
	jekyll clean

publish: build
	echo -e "\033[32mPublishing the site...\033[0m"
	cd ../stamak.github.io/ && \
	rm -rf * && \
	cp -av ../gh-pages-src/_site/* . && \
	git --no-pager diff && \
	git status && \
	git add . && \
	git commit --amend -m "Add Jekull generated static page" && \
	git push -f -u origin main 

build: clean
	echo -e "\033[32mBuilding _site content...\033[0m"
	JEKYLL_ENV=production jekyll build

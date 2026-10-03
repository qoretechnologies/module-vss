#!/usr/bin/python3
# Copyright (C) 2026 Qore Technologies, s.r.o.
# SPDX-License-Identifier: MIT
"""Check the shared documentation theme, assets, links, and VSS directive text."""
from html.parser import HTMLParser
from pathlib import Path
import sys
import unittest
from urllib.parse import unquote, urlsplit

DOCS = Path(sys.argv.pop(1)).resolve()


class Page(HTMLParser):
    def __init__(self, path):
        super().__init__()
        self.links = []
        self.stylesheets = []
        self.icons = []
        self.assets = []
        self.ids = set()
        self.text = []
        self.feed(path.read_text())

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'a' and 'href' in attrs:
            self.links.append(attrs['href'])
        if tag == 'link' and 'href' in attrs:
            rel = attrs.get('rel', '').split()
            if 'stylesheet' in rel:
                self.stylesheets.append(attrs['href'])
            if 'icon' in rel:
                self.icons.append(attrs['href'])
            if 'stylesheet' in rel or 'icon' in rel:
                self.assets.append(attrs['href'])
        if tag in ('img', 'script') and 'src' in attrs:
            self.assets.append(attrs['src'])
        if 'id' in attrs:
            self.ids.add(attrs['id'])

    def handle_data(self, data):
        self.text.append(data)


class DocsTest(unittest.TestCase):
    def test_shared_theme_and_assets_on_overview_guides_and_api_pages(self):
        reference = DOCS / 'VssLoader/html'
        for module in ('vss', 'VssLoader', 'VssDataProvider'):
            directory = DOCS / module / 'html'
            pages = [path for path in directory.glob('*.html') if path.name != 'doxygen_crawl.html']
            self.assertTrue(pages, module)
            for path in pages:
                with self.subTest(page=path):
                    page = Page(path)
                    self.assertIn('dox_qore.css', page.stylesheets)
                    self.assertIn('Qore-Q.ico', page.icons)
                    self.assertIn('qore-logo-55x151-white.png', page.assets)
                    for asset in page.assets:
                        url = urlsplit(asset)
                        if not url.scheme and not url.netloc:
                            self.assertTrue((directory / unquote(url.path)).is_file(), asset)
            for asset in ('dox_qore.css', 'Qore-Q.ico', 'qore-logo-55x151-white.png'):
                self.assertEqual((reference / asset).read_bytes(), (directory / asset).read_bytes(),
                                 f'{module}: {asset}')

    def test_overview_release_notes_and_local_links(self):
        path = DOCS / 'vss/html/index.html'
        page = Page(path)
        self.assertIn('vssreleasenotes', page.ids)
        self.assertEqual((DOCS / 'vss/html/COPYING.MIT').read_text(),
                         (Path(__file__).resolve().parents[1] / 'COPYING.MIT').read_text())
        for module in ('VssLoader', 'VssDataProvider'):
            links = [urlsplit(link).path for link in page.links if f'/{module}/html/' in link]
            self.assertTrue(links, module)
            for link in links:
                self.assertTrue((path.parent / unquote(link)).is_file(), link)

    def test_bundled_api_links_and_include_directives(self):
        pages = [Page(path) for path in (DOCS / 'VssDataProvider/html').glob('*.html')]
        links = [link for page in pages for link in page.links]
        for module in ('DataProvider', 'reflection', 'json', 'yaml'):
            self.assertTrue(any(f'/modules/{module}/html/' in link for link in links), module)
        parser_pages = list((DOCS / 'VssLoader/html').glob('*VssVspecParser*.html'))
        self.assertTrue(parser_pages)
        text = ''.join(''.join(Page(path).text) for path in parser_pages)
        self.assertIn('#include', text)
        self.assertNotIn('\\#include', text)


if __name__ == '__main__':
    unittest.main()

"""Generate tiny, original EPUB fixtures covering real container/spine behavior."""
from pathlib import Path
import zipfile

root = Path(__file__).resolve().parents[1] / "Tests/YomuCoreTests/Fixtures"
root.mkdir(exist_ok=True)
container = '<?xml version="1.0"?><container xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="OPS/package.opf" media-type="application/oebps-package+xml"/></rootfiles></container>'
package = '''<?xml version="1.0"?><package xmlns="http://www.idpf.org/2007/opf" version="3.0"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:title>日本語の旅</dc:title><dc:creator>Yomu Tests</dc:creator></metadata><manifest><item id="first" href="Text/first.xhtml" media-type="application/xhtml+xml"/><item id="second" href="Text/second.xhtml" media-type="application/xhtml+xml"/></manifest><spine><itemref idref="second"/><itemref idref="first"/></spine></package>'''
first = '<html xmlns="http://www.w3.org/1999/xhtml"><head><title>First</title><style>DO NOT INCLUDE STYLE</style></head><body><h1>後の章</h1><p>友達と学校で勉強します。</p></body></html>'
second = '<html xmlns="http://www.w3.org/1999/xhtml"><head><title>Second</title></head><body><h1>最初の章</h1><p><ruby>日本語<rt>にほんご</rt><rp>(</rp></ruby>の本を読みます。</p><script>DO NOT INCLUDE SCRIPT</script><p>静かな朝です。</p></body></html>'
for name, method in [("stored.epub", zipfile.ZIP_STORED), ("deflated.epub", zipfile.ZIP_DEFLATED), ("protected.epub", zipfile.ZIP_DEFLATED), ("traversal.epub", zipfile.ZIP_STORED)]:
    with zipfile.ZipFile(root / name, "w", method) as archive:
        archive.writestr("mimetype", "application/epub+zip", compress_type=zipfile.ZIP_STORED)
        archive.writestr("META-INF/container.xml", container)
        archive.writestr("OPS/package.opf", package)
        archive.writestr("OPS/Text/first.xhtml", first)
        archive.writestr("OPS/Text/second.xhtml", second)
        if name == "protected.epub":
            archive.writestr("META-INF/encryption.xml", '<encryption><EncryptedData><CipherData><CipherReference URI="OPS/Text/second.xhtml"/></CipherData></EncryptedData></encryption>')
        if name == "traversal.epub":
            archive.writestr("../../outside.txt", "Must never be written")
(root / "japanese.txt").write_text("日本語の本を読みます。\n\n今日はいい天気です。", encoding="utf-8")
(root / "shift-jis.txt").write_bytes("日本語の本を読みます。".encode("shift_jis"))
print(f"Created fixtures in {root}")

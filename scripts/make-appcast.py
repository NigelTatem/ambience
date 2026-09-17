#!/usr/bin/env python3
"""Create a one-release Sparkle feed; the update archive signature is mandatory."""
import base64
import email.utils
import pathlib
import plistlib
import sys
import xml.etree.ElementTree as ET

def make_feed(plist_path, archive_path, signature, output_path):
    plist = plistlib.loads(pathlib.Path(plist_path).read_bytes())
    if len(base64.b64decode(signature, validate=True)) != 64:
        raise ValueError('Expected a 64-byte Ed25519 archive signature')
    version = plist['CFBundleShortVersionString']
    archive = pathlib.Path(archive_path)
    namespace = 'http://www.andymatuschak.org/xml-namespaces/sparkle'
    ET.register_namespace('sparkle', namespace)
    root = ET.Element('rss', version='2.0')
    channel = ET.SubElement(root, 'channel')
    ET.SubElement(channel, 'title').text = 'Ambience updates'
    ET.SubElement(channel, 'link').text = 'https://github.com/NigelTatem/ambience'
    ET.SubElement(channel, 'description').text = 'Free video wallpaper for Mac'
    item = ET.SubElement(channel, 'item')
    ET.SubElement(item, 'title').text = 'Ambience ' + version
    ET.SubElement(item, 'pubDate').text = email.utils.formatdate(usegmt=True)
    ET.SubElement(item, '{%s}version' % namespace).text = str(plist['CFBundleVersion'])
    ET.SubElement(item, '{%s}shortVersionString' % namespace).text = version
    ET.SubElement(item, '{%s}minimumSystemVersion' % namespace).text = plist['LSMinimumSystemVersion']
    ET.SubElement(item, 'enclosure', {
        'url': f'https://github.com/NigelTatem/ambience/releases/download/v{version}/{archive.name}',
        'length': str(archive.stat().st_size),
        'type': 'application/octet-stream',
        '{%s}edSignature' % namespace: signature,
    })
    ET.indent(root)
    ET.ElementTree(root).write(output_path, encoding='utf-8', xml_declaration=True)

if __name__ == '__main__':
    make_feed(*sys.argv[1:])

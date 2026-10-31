#!/usr/bin/env python3
"""Called by the production Release build. No network, source edits or side effects."""
import re
import sys
from urllib.parse import urlparse
import release as r
from compile_bundle import verify_generated

def publisher_valid(value):
    r.require(value.get('displayName','').strip(),'publisher: real publishing name is required')
    r.require(re.fullmatch(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}',value.get('supportEmail','')),'publisher: support email is required')
    url=urlparse(value.get('privacyPolicyURL',''));host=url.hostname or ''
    r.require(url.scheme=='https' and host and not url.username and not url.password and host not in ('example.com','example.org','example.net') and not host.endswith('.invalid'),'publisher: real HTTPS privacy policy URL is required')

if __name__=='__main__':
    try:
        publisher_valid(r.read(r.ROOT/'ios/Configuration/Publisher.json'))
        receipt=verify_generated(r.ROOT/'ios/ApprovedContent',r.read(r.ROOT/'resource/content/reviewers.json'),r.ROOT/'resource/content/source')
        print('Approved content verified:',receipt['packageId'])
    except (r.Invalid,OSError,ValueError,KeyError) as error:
        sys.exit('error: Release gate rejected this build: '+str(error))

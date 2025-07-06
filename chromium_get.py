#!/usr/bin/env python3
"""fetch pages from a website, looking as much like a human as possible"""
# If they just had a data endpoint, I would use it ..

# :dotsctl:
#   dpkg:
#     - chromium-driver
#     - python3-selenium
# ...

import argparse
import selenium.webdriver
import shutil
import time


def argparser():
    args = argparse.ArgumentParser(description=__doc__)

    args.add_argument(
        "-v", "--verbose",
        action='store_true', default=False,
        help="Set verbose output",
    )

    args.add_argument(
        "--pause",
        default=0,
        help="Pause seconds after each url",
    )

    args.add_argument(
        "--prefix",
        default="",
        help="Prefix for output filenames",
    )

    args.add_argument(
        "--urls",
        default=None,
        type=argparse.FileType('r'),
        help="File to load URLs list from",
    )

    args.add_argument(
        "--newsession",
        default=False,
        action="store_true",
        help="Start a new browser session for each url",
    )

    args.add_argument(
        "--fix-new-selenium",
        default=False,
        action="store_true",
        help="Bypass some new horror by finding and providing a driver path",
    )

    args.add_argument(
        "url",
        nargs='*',
        help="Add URLs from commandline",
    )

    r = args.parse_args()
    return r


browser = None
fix_new_selenium = False

def browser_session():
    global browser
    global fix_new_selenium

    if browser is not None:
        # Just use the existing session
        return

    opt = selenium.webdriver.ChromeOptions()
    svc = selenium.webdriver.chrome.service.Service()

    if fix_new_selenium:
        # Found on Ubuntu 24.04, which has selenium 4.18.  Not needed on
        # Debian bookworm, which has selenium 4.8
        #
        # It seems that they have added some binary "selenium-manager" thing
        # that exists to "help" you by downloading random rootkits ^w browsers
        # from the internet.  The python interface to this thing doesnt even
        # bother to check if the right driver is *simply*on*the*path* and just
        # fails because it cannot find this manager binary.
        #
        # Attempt to tell it to take a jump by doing that path check ourselves
        svc.path = shutil.which("chromedriver")

    # While this does work, some websites detect the user as not having
    # javascript turned on - so it is not actully useful
    # opt.add_argument("--headless=new")

    browser = selenium.webdriver.Chrome(service=svc, options=opt)


def do_one_url(args, fileindex, url):
    filename = f"{args.prefix}{fileindex}.html"

    global browser
    browser_session()

    if args.verbose:
        print(f"GET {url}", flush=True)
    browser.get(url)

    f = open(filename, "w")
    f.write(browser.page_source)
    if args.verbose:
        print(f"GOT {filename}", flush=True)

    time.sleep(int(args.pause))

    if args.newsession:
        browser = None


def main():
    args = argparser()

    global fix_new_selenium
    fix_new_selenium = args.fix_new_selenium

    i = 0
    for url in args.url:
        do_one_url(args, i, url)
        i += 1

    if args.urls is None:
        return

    for url in args.urls.readlines():
        url = url.strip()

        # skip comments and blanks
        if url.startswith("#"):
            continue
        if not url:
            continue

        do_one_url(args, i, url)
        i += 1


if __name__ == "__main__":
    main()

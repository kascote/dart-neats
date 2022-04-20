// Copyright 2019 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:test/test.dart';
import 'package:sanitize_html/sanitize_html.dart'
    show sanitizeHtml, AllowTagCB, AllowAttributeCB, AllowAttributeResponse;

final otherTagList = <String>{'CSTM', 'A', 'IFRAME'};
final _removeContentTagList = <String>{'CUSTOM'};
bool customTagList(String t) => otherTagList.contains(t);
bool removeContentTagList(String t) => _removeContentTagList.contains(t);
AllowAttributeResponse customAttrList(
    String tag, String attrName, String attrValue) {
  if (attrName.toUpperCase() == 'CLASS') {
    final k = attrValue.split(' ');
    k.removeWhere((v) => !v.endsWith('allowed'));
    return AllowAttributeResponse.edit(k.join(' '));
  }
  if (tag.toUpperCase() == 'DIV') {
    if (attrName.toUpperCase() == 'ALT') {
      return AllowAttributeResponse.unchanged();
    }
    return AllowAttributeResponse.remove();
  }
  if (attrName.toUpperCase() == 'DATA-KEY') {
    return AllowAttributeResponse.edit('new-value');
  }
  return AllowAttributeResponse.remove();
}

void main() {
  // Calls sanitizeHtml with two different configurations.
  //  * When `withOptionalConfiguration` is `true`: `allowElementId`, `allowClassName`
  // and `addLinkRel` overrides are passed to the sanitizeHtml call of `template`.
  // (This is the default behavior for the [testContains]/[testNotContains] methods.)
  //  * When `withOptionalConfiguration` is false: only `template` is passed.
  String doSanitizeHtml(
    String template, {
    required bool withOptionalConfiguration,
    AllowTagCB? withCustomTagList,
    AllowAttributeCB? withCustomAttrList,
    AllowTagCB? withRemoveContentTagList,
    bool withRemoveContent = true,
  }) {
    if (!withOptionalConfiguration) {
      return sanitizeHtml(
        template,
        allowTag: withCustomTagList,
        allowAttribute: withCustomAttrList,
        removeContentTag: withRemoveContentTagList,
        removeContents: withRemoveContent,
      );
    }

    return sanitizeHtml(
      template,
      allowElementId: (id) => id == 'only-allowed-id',
      allowClassName: (className) => className == 'only-allowed-class',
      addLinkRel: (href) => href == 'bad-link' ? ['ugc', 'nofollow'] : null,
      allowTag: withCustomTagList,
      allowAttribute: withCustomAttrList,
      removeContentTag: withRemoveContentTagList,
      removeContents: withRemoveContent,
    );
  }

  void testContains(
    String template,
    String needle, {
    bool withOptionalConfiguration = true,
    AllowTagCB? withCustomTagList,
    AllowAttributeCB? withCustomAttrList,
    AllowTagCB? withRemoveContentTagList,
    bool withRemoveContent = true,
  }) {
    test('"$template" does contain "$needle"', () {
      final sanitizedHtml = doSanitizeHtml(
        template,
        withOptionalConfiguration: withOptionalConfiguration,
        withCustomTagList: withCustomTagList,
        withCustomAttrList: withCustomAttrList,
        withRemoveContentTagList: withRemoveContentTagList,
        withRemoveContent: withRemoveContent,
      );
      expect(sanitizedHtml, contains(needle));
    });
  }

  void testNotContains(
    String template,
    String needle, {
    bool withOptionalConfiguration = true,
    AllowTagCB? withCustomTagList,
    AllowAttributeCB? withCustomAttrList,
    AllowTagCB? withRemoveContentTagList,
    bool withRemoveContent = true,
  }) {
    test('"$template" does not contain "$needle"', () {
      final sanitizedHtml = doSanitizeHtml(
        template,
        withOptionalConfiguration: withOptionalConfiguration,
        withCustomTagList: withCustomTagList,
        withCustomAttrList: withCustomAttrList,
        withRemoveContentTagList: withRemoveContentTagList,
        withRemoveContent: withRemoveContent,
      );
      expect(sanitizedHtml, isNot(contains(needle)));
    });
  }

  testNotContains('test', '<br>');
  testContains('test', 'test');
  testContains('a < b', '&lt;');
  testContains('a < b > c', '&gt;');
  testContains('<p>hello', 'hello');
  testContains('<p>hello', '</p>');
  testContains('<p>hello', '<p>');

  // test id filtering..
  testContains('<span id="only-allowed-id">hello</span>', 'id');
  testContains('<span id="only-allowed-id">hello</span>', 'only-allowed-id');
  testNotContains('<span id="disallowed-id">hello</span>', 'id');
  testNotContains('<span id="disallowed-id">hello</span>', 'only-allowed-id');

  // test class filtering
  testContains('<span class="only-allowed-class">hello</span>', 'class');
  testContains(
      '<span class="only-allowed-class">hello</span>', 'only-allowed-class');
  testContains('<span class="only-allowed-class disallowed-class">hello</span>',
      'class="only-allowed-class"');
  testNotContains('<span class="disallowed-class">hello</span>', 'class');
  testNotContains(
      '<span class="disallowed-class">hello</span>', 'only-allowed-class');

  testContains('<a href="test.html">hello', 'href');
  testContains('<a href="test.html">hello', 'test.html');
  testContains(
      '<a href="//example.com/test.html">hello', '//example.com/test.html');
  testContains('<a href="/test.html">hello', '/test.html');
  testContains('<a href="https://example.com/test.html">hello',
      'https://example.com/test.html');
  testContains('<a href="http://example.com/test.html">hello',
      'http://example.com/test.html');
  testContains(
      '<a href="mailto:test@example.com">hello', 'mailto:test@example.com');

  testContains('<img src="test.jpg"/>', '<img');
  testContains('<img src="test.jpg" alt="say hi"/>', 'say hi');
  testContains('<img src="test.jpg" alt="say hi"/>', 'alt=');
  testContains('<img src="test.jpg" ALt="say hi"/>', 'say hi');
  testContains('<img src="test.jpg" ALT="say hi"/>', 'alt=');
  testContains('<img src="test.jpg"/>', 'src=');
  testContains('<img src="test.jpg"/>', 'test.jpg');
  testContains('<img src="//test.jpg"/>', '//test.jpg');
  testContains('<img src="/test.jpg"/>', '/test.jpg');
  testContains('<img src="https://example.com/test.jpg"/>',
      'https://example.com/test.jpg');
  testContains('<img src="http://example.com/test.jpg"/>',
      'http://example.com/test.jpg');

  testNotContains('<img src="javascript:test.jpg"/>', 'src=');
  testNotContains('<img src="javascript:test.jpg"/>', 'javascript');
  testContains('<img src="javascript:test.jpg"/>', 'img');
  testNotContains('<script/>', 'script');
  testNotContains('<script src="example.js"/>', 'script');
  testNotContains('<script src="example.js"/>', 'src');
  testContains('<script>alert("bad")</script> hello world', 'hello world');
  testNotContains('<script>alert("bad")</script> hello world', 'bad');
  testContains('<a href="javascript:alert()">evil link</a>', '<a');
  testNotContains('<a href="javascript:alert()">evil link</a>', 'href');
  testNotContains('<a href="javascript:alert()">evil link</a>', 'alert');
  testNotContains('<a href="javascript:alert()">evil link</a>', 'javascript');

  testNotContains('<form><input type="submit"/></form> click here', 'form');
  testNotContains('<form><input type="submit"/></form> click here', 'submit');
  testNotContains('<form><input type="submit"/></form> click here', 'input');
  testContains('<form><input type="submit"/></form> click here', 'click here');

  testContains('<br>', '<br>');
  testNotContains('<br>', '</br>');
  testNotContains('<br>', '</ br>');
  testContains('><', '&gt;&lt;');
  testContains('<div><div id="x">a</div></div>', '<div><div>a</div></div>');
  testContains('<a href="a.html">a</a><a href="b.html">b</a>',
      '<a href="a.html">a</a><a href="b.html">b</a>');

  // test void elements
  testContains('<strong></strong> hello', '<strong>');
  testContains('<strong></strong> hello', '</strong>');
  testNotContains('<strong></strong> hello', '<strong />');
  testContains('<br>hello</br>', '<br>');
  testNotContains('<br>hello</br>', '</br>');
  testNotContains('<br>hello</br>', '</ br>');

  // test addLinkRel
  testContains('<a href="bad-link">hello', 'bad-link');
  testContains('<a href="bad-link">hello', 'rel="ugc nofollow"');
  testNotContains('<a href="good-link">hello', 'rel="ugc nofollow"');

  group('Optional parameters stay optional:', () {
    // If any of these fail, it probably means a major version bump is required.
    testContains('<a href="any-href">hey', 'href=',
        withOptionalConfiguration: false);
    testNotContains('<a href="any-href">hey', 'rel=',
        withOptionalConfiguration: false);
    testNotContains('<span id="any-id">hello</span>', 'id=',
        withOptionalConfiguration: false);
    testNotContains('<span class="any-class">hello</span>', 'class=',
        withOptionalConfiguration: false);
  });

  group('Custom Tag List: ', () {
    testContains('<cstm>hello', '<cstm>hello',
        withCustomTagList: customTagList);
    testNotContains('<div>hello', 'hello', withCustomTagList: customTagList);

    // custom tags with support for attributes
    testContains('<cstm id="only-allowed-id">hello</cstm>', 'id',
        withCustomTagList: customTagList);
    testContains('<cstm id="only-allowed-id">hello</cstm>', 'only-allowed-id',
        withCustomTagList: customTagList);
    testNotContains('<cstm id="disallowed-id">hello</cstm>', 'id',
        withCustomTagList: customTagList);
    testNotContains('<cstm id="disallowed-id">hello</cstm>', 'only-allowed-id',
        withCustomTagList: customTagList);
    // default rules for A attribute do not works when use customTagList
    testNotContains('<a href="bad-link">hello', 'rel="ugc nofollow"',
        withCustomTagList: customTagList);

    testContains('<a href="any-href">hey', 'href=',
        withOptionalConfiguration: false, withCustomTagList: customTagList);
    testNotContains('<a href="any-href">hey', 'rel=',
        withOptionalConfiguration: false, withCustomTagList: customTagList);
    testNotContains('<cstm id="any-id">hello</cstm>', 'id=',
        withOptionalConfiguration: false, withCustomTagList: customTagList);
    testNotContains('<cstm class="any-class">hello</cstm>', 'class=',
        withOptionalConfiguration: false, withCustomTagList: customTagList);

    // custom tag list handle default allowed attributes if AllowAttributes is missing
    testContains('<cstm alt="bar">hello', 'alt',
        withCustomTagList: customTagList);
  });

  group('Custom Attribute List: ', () {
    testNotContains('<span alt="foo">hello', 'alt',
        withCustomAttrList: customAttrList);
    testContains('<div alt="foo">hello', 'alt',
        withCustomAttrList: customAttrList);
    testNotContains('<div bar="foo">hello', 'bar',
        withCustomAttrList: customAttrList);
    testNotContains('<span class="foo-allowed other-attr">hello', 'other-attr',
        withCustomAttrList: customAttrList);
    testContains('<span class="foo-allowed other-attr">hello', 'foo-allowed',
        withCustomAttrList: customAttrList);
    testContains('<span data-key="value-allowed">hello', 'new-value',
        withCustomAttrList: customAttrList);
    testNotContains('<span data-key="value-allowed">hello', 'value-allowed',
        withCustomAttrList: customAttrList);
  });

  group('Remove tag but left content: ', () {
    testNotContains('<font>hello', 'font', withRemoveContent: false);
    testContains('<font>hello', 'hello', withRemoveContent: false);
    // allowed default tags (parent/children)
    testContains(
        '<form>up<input type="submit"/><h1>hello<span>world</h1><some>down',
        'up<h1>hello<span>world</span></h1>down',
        withRemoveContent: false);
    // allowed default tags (parent/siblings)
    testContains('<font>up</font><h1>hello</h1><some>down</some>',
        'up<h1>hello</h1>down',
        withRemoveContent: false);

    // unknown tags
    testContains(
        '<form>up<input type="submit"/><foo>hello<bar>world', 'uphelloworld',
        withRemoveContent: false);

    // some tags always remove content
    testNotContains('<iframe>badBad', 'badBad', withRemoveContent: false);
    testNotContains('<iframe>badBad<div>noNo', 'noNo',
        withRemoveContent: false);

    // custom tags with keep content
    testContains('<cstm>foo<b>bar', 'foobar',
        withRemoveContent: false, withCustomTagList: customTagList);
    // if the node to remove has children, will generate with a wrapper
    testContains('<span>foo<cstm>bar', '<div>foo<cstm>bar</cstm></div>',
        withRemoveContent: false, withCustomTagList: customTagList);
    // if the node to remove do not has children, generate a text node
    testContains('<span>foo</span><cstm>bar', 'foo<cstm>bar',
        withRemoveContent: false, withCustomTagList: customTagList);

    // when use custom tags, will not use the default disalowed tags
    testContains('<iframe>badBad', '<iframe>badBad',
        withRemoveContent: false, withCustomTagList: customTagList);
    testNotContains('<script>badBad', 'badBad',
        withRemoveContent: false, withCustomTagList: customTagList);

    testNotContains('<custom>hello', 'hello',
        withRemoveContent: false,
        withRemoveContentTagList: removeContentTagList);
    testContains('<custom2>hello', 'hello',
        withRemoveContent: false,
        withRemoveContentTagList: removeContentTagList);

    // when use custom list, default disallowed tag list is not used but the tag is removed
    testContains('<iframe>hello', 'hello',
        withRemoveContent: false,
        withRemoveContentTagList: removeContentTagList);
    testNotContains('<iframe>hello', 'iframe',
        withRemoveContent: false,
        withRemoveContentTagList: removeContentTagList);

    testContains('<iframe>hello', '<iframe>hello',
        withRemoveContent: false,
        withCustomTagList: customTagList,
        withRemoveContentTagList: removeContentTagList);
    testNotContains('<custom>hello', 'hello',
        withRemoveContent: false,
        withCustomTagList: customTagList,
        withRemoveContentTagList: removeContentTagList);
    testContains('<some>hello', 'hello',
        withRemoveContent: false,
        withCustomTagList: customTagList,
        withRemoveContentTagList: removeContentTagList);
  });
}

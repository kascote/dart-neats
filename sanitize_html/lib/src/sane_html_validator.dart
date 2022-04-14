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

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

final _allowedElements = <String>{
  'H1',
  'H2',
  'H3',
  'H4',
  'H5',
  'H6',
  'H7',
  'H8',
  'BR',
  'B',
  'I',
  'STRONG',
  'EM',
  'A',
  'PRE',
  'CODE',
  'IMG',
  'TT',
  'DIV',
  'INS',
  'DEL',
  'SUP',
  'SUB',
  'P',
  'OL',
  'UL',
  'TABLE',
  'THEAD',
  'TBODY',
  'TFOOT',
  'BLOCKQUOTE',
  'DL',
  'DT',
  'DD',
  'KBD',
  'Q',
  'SAMP',
  'VAR',
  'HR',
  'RUBY',
  'RT',
  'RP',
  'LI',
  'TR',
  'TD',
  'TH',
  'S',
  'STRIKE',
  'SUMMARY',
  'DETAILS',
  'CAPTION',
  'FIGURE',
  'FIGCAPTION',
  'ABBR',
  'BDO',
  'CITE',
  'DFN',
  'MARK',
  'SMALL',
  'SPAN',
  'TIME',
  'WBR',
};

final _alwaysAllowedAttributes = <String>{
  'abbr',
  'accept',
  'accept-charset',
  'accesskey',
  'action',
  'align',
  'alt',
  'aria-describedby',
  'aria-hidden',
  'aria-label',
  'aria-labelledby',
  'axis',
  'border',
  'cellpadding',
  'cellspacing',
  'char',
  'charoff',
  'charset',
  'checked',
  'clear',
  'cols',
  'colspan',
  'color',
  'compact',
  'coords',
  'datetime',
  'dir',
  'disabled',
  'enctype',
  'for',
  'frame',
  'headers',
  'height',
  'hreflang',
  'hspace',
  'ismap',
  'label',
  'lang',
  'maxlength',
  'media',
  'method',
  'multiple',
  'name',
  'nohref',
  'noshade',
  'nowrap',
  'open',
  'prompt',
  'readonly',
  'rel',
  'rev',
  'rows',
  'rowspan',
  'rules',
  'scope',
  'selected',
  'shape',
  'size',
  'span',
  'start',
  'summary',
  'tabindex',
  'target',
  'title',
  'type',
  'usemap',
  'valign',
  'value',
  'vspace',
  'width',
  'itemprop',
};

bool _alwaysAllowed(String _) => true;

bool _validLink(String url) {
  try {
    final uri = Uri.parse(url);
    return uri.isScheme('https') ||
        uri.isScheme('http') ||
        uri.isScheme('mailto') ||
        !uri.hasScheme;
  } on FormatException {
    return false;
  }
}

bool _validUrl(String url) {
  try {
    final uri = Uri.parse(url);
    return uri.isScheme('https') || uri.isScheme('http') || !uri.hasScheme;
  } on FormatException {
    return false;
  }
}

final _citeAttributeValidator = <String, bool Function(String)>{
  'cite': _validUrl,
};

final _elementAttributeValidators =
    <String, Map<String, bool Function(String)>>{
  'A': {
    'href': _validLink,
  },
  'IMG': {
    'src': _validUrl,
    'longdesc': _validUrl,
  },
  'DIV': {
    'itemscope': _alwaysAllowed,
    'itemtype': _alwaysAllowed,
  },
  'BLOCKQUOTE': _citeAttributeValidator,
  'DEL': _citeAttributeValidator,
  'INS': _citeAttributeValidator,
  'Q': _citeAttributeValidator,
};

/// Callback function used to check wich tags are allowed
/// The function will return true if the tag is allowed of false if not.
typedef AllowTagCB = bool Function(String tag);

/// Callback function used to check wich attributes are allowed
/// The function will return an [AllowAttributeResponse] object
/// with the result of the check.
typedef AllowAttributeCB = AllowAttributeResponse Function(
    String tag, String attribute, String value);

/// Possible outcome actions of [AllowAttributeResponse]
enum ResponseAction {
  unchanged,
  edit,
  remove,
}

/// Response object returned by [AllowAttributeCB]
/// The [action] attribute determine the action to take
/// and can be [unchanged], [edit] or [remove].
/// In case of [edit], the [value] field can be used to
/// change the content of the attribute.
class AllowAttributeResponse {
  ResponseAction action;
  String value;

  AllowAttributeResponse(this.action, [this.value = '']);

  /// Factory function for unchaged action
  factory AllowAttributeResponse.unchanged() =>
      AllowAttributeResponse(ResponseAction.unchanged);

  /// Factory function for edit action
  factory AllowAttributeResponse.edit(String value) =>
      AllowAttributeResponse(ResponseAction.edit, value);

  /// Factory function for remove action
  factory AllowAttributeResponse.remove() =>
      AllowAttributeResponse(ResponseAction.remove);
}

/// An implementation of [html.NodeValidator] that only allows sane HTML tags
/// and attributes protecting against XSS.
///
/// Modeled after the [rules employed by Github][1] when sanitizing GFM (Github
/// Flavored Markdown). Notably this excludes CSS styles and other tags that
/// easily interferes with the rest of the page.
///
/// [1]: https://github.com/jch/html-pipeline/blob/master/lib/html/pipeline/sanitization_filter.rb
class SaneHtmlValidator {
  final bool Function(String)? allowElementId;
  final bool Function(String)? allowClassName;
  final Iterable<String>? Function(String)? addLinkRel;

  /// Callback function to check for allowed tags
  final AllowTagCB? allowTag;

  /// Callback function to check for allowed attributes
  final AllowAttributeCB? allowAttribute;

  late AllowTagCB _allowTagFn;
  late AllowAttributeCB _allowAttributeFn;

  SaneHtmlValidator({
    required this.allowElementId,
    required this.allowClassName,
    required this.addLinkRel,
    required this.allowTag,
    required this.allowAttribute,
  }) {
    _allowTagFn = allowTag ?? _defaultAllowedElements;
    _allowAttributeFn = allowAttribute ?? _defaultAllowedAttributes;
  }

  String sanitize(String htmlString) {
    final root = html_parser.parseFragment(htmlString);
    _sanitize(root);
    return root.outerHtml;
  }

  bool _defaultAllowedElements(String tagName) =>
      _allowedElements.contains(tagName);

  AllowAttributeResponse _defaultAllowedAttributes(
      String tagName, String attrName, String attrValue) {
    if (attrName == 'id') {
      if (allowElementId == null) return AllowAttributeResponse.remove();
      return allowElementId!(attrValue)
          ? AllowAttributeResponse.unchanged()
          : AllowAttributeResponse.remove();
    }
    if (attrName == 'class') {
      if (allowClassName == null) return AllowAttributeResponse.remove();
      final klasses = attrValue.split(' ');
      klasses.removeWhere((cn) => !allowClassName!(cn));
      return klasses.isEmpty
          ? AllowAttributeResponse.remove()
          : AllowAttributeResponse.edit(klasses.join(' '));
    }
    return _isAttributeAllowed(tagName, attrName, attrValue)
        ? AllowAttributeResponse.unchanged()
        : AllowAttributeResponse.remove();
  }

  void _sanitize(Node node) {
    if (node is Element) {
      final tagName = node.localName!.toUpperCase();
      if (!_allowTagFn(tagName)) {
        node.remove();
        return;
      }
      node.attributes.removeWhere((k, v) {
        final attrName = k.toString();
        final rc = _allowAttributeFn(tagName, attrName, v);
        if (rc.action == ResponseAction.remove) return true;
        if (rc.action == ResponseAction.edit) {
          if (attrName == 'class') {
            final klasses = rc.value.split(' ');
            node.classes.removeWhere((klass) => !klasses.contains(klass));
          } else {
            node.attributes[k] = rc.value;
          }
          return false;
        }
        return false;
      });
      // When use a custom tag list, the default rule for anchor/rel will not work
      if ((allowTag == null) && (tagName == 'A')) {
        final href = node.attributes['href'];
        if (href != null && addLinkRel != null) {
          final rels = addLinkRel!(href);
          if (rels != null && rels.isNotEmpty) {
            node.attributes['rel'] = rels.join(' ');
          }
        }
      }
    }
    if (node.hasChildNodes()) {
      // doing it in reverse order, because we could otherwise skip one, when a
      // node is removed...
      for (var i = node.nodes.length - 1; i >= 0; i--) {
        _sanitize(node.nodes[i]);
      }
    }
  }

  bool _isAttributeAllowed(String tagName, String attrName, String value) {
    if (_alwaysAllowedAttributes.contains(attrName)) return true;

    // Special validators for special attributes on special tags (href/src/cite)
    final attributeValidators = _elementAttributeValidators[tagName];
    if (attributeValidators == null) {
      return false;
    }

    final validator = attributeValidators[attrName];
    if (validator == null) {
      return false;
    }

    return validator(value);
  }
}

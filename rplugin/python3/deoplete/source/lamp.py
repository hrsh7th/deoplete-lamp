import json
import re
from deoplete.source.base import Base

# @see https://microsoft.github.io/language-server-protocol/specification#textDocument_completion
COMPLETION_ITEM_KIND = [
    'Text',
    'Method',
    'Function',
    'Constructor',
    'Field',
    'Variable',
    'Class',
    'Interface',
    'Module',
    'Property',
    'Unit',
    'Value',
    'Enum',
    'Keyword',
    'Snippet',
    'Color',
    'File',
    'Reference',
    'Folder',
    'EnumMember',
    'Constant',
    'Struct',
    'Event',
    'Operator',
    'TypeParameter',
]

class Source(Base):
    def __init__(self, vim):
        Base.__init__(self, vim)

        self.name = 'lamp'
        self.mark = '[LAMP]'
        self.rank = 10000
        self.input_pattern = r'.$'
        self.min_pattern_length = 0
        self.is_volatile = True
        self.sorters = []
        self.vars = {}
        self.dub = True
        self.id = 0

    def gather_candidates(self, context):
        if not self.vim.call('deoplete_lamp#is_completable'):
            return []

        request = self.vim.call('deoplete_lamp#find_request', {
            'line': self.vim.call('line', '.') - 1,
            'character': context['complete_position'] + 1
        })

        if request:
            if request['responses']:
                return self.to_candidates(request)
            return []
        else:
            self.vim.call('deoplete_lamp#request')
        return []

    def to_candidates(self, request):
        candidates = []

        for response in self.normalize_responses(request['responses']):
            items = sorted(response['items'], key=get_sort_key)
            for item in items:
                word = item.get('insertText', item['label'])
                is_expandable = False
                if item.get('insertTextFormat') == 2 and 'insertText' in item:
                    word = item['label']
                    is_expandable = item['insertText'] != word
                elif 'textEdit' in item:
                    word = item['label']
                    is_expandable = item['textEdit']['newText'] != word

                candidates.append({
                    'word': word,
                    'abbr': '{}~'.format(word) if is_expandable else word,
                    'kind': COMPLETION_ITEM_KIND[item['kind'] - 1 if 'kind' in item else 0] + ' ' + re.sub('(\r\n|\r|\n)', '', item.get('detail', '')),
                    'user_data': self.user_data(response['server_name'], item)
                })
        return candidates

    def normalize_responses(self, responses):
        results = []
        for response in responses:
            if 'data' not in response:
                continue

            if isinstance(response['data'], list):
                results.append({
                    'server_name': response['server_name'],
                    'isIncomplete': False,
                    'items': response['data']
                })
            elif isinstance(response['data'], dict):
                results.append({
                    'server_name': response['server_name'],
                    'isIncomplete': response['data'].get('isIncomplete', True),
                    'items': response['data']['items']
                })
        return results

    def user_data(self, server_name, item):
        self.id += 1
        return json.dumps({
            'lamp': {
                'id': self.id,
                'server_name': server_name,
                'completion_item': item
            }
        })

def get_sort_key(item):
    if item.get('preselect', None) is not None:
        return '0'
    return item.get('sortText', item['label'])


import clsx from 'clsx'
import { computed, defineComponent, type Ref, h, type VNodeRef } from 'vue'

import type { ListItemBlockConfig } from './config'

import { Icon } from '../__internal__/components/icon'
import { keepAlive } from '../__internal__/keep-alive'

keepAlive(h)

interface Attrs {
  label: string
  checked: boolean
  listType: string
}

type ListItemProps = {
  [P in keyof Attrs]: Ref<Attrs[P]>
} & {
  config: ListItemBlockConfig
  readonly: Ref<boolean>
  selected: Ref<boolean>
  setAttr: <T extends keyof Attrs>(attr: T, value: Attrs[T]) => void
  onMount: (div: Element) => void
}

export const ListItem = defineComponent<ListItemProps>({
  props: {
    label: {
      type: Object,
      required: true,
    },
    checked: {
      type: Object,
      required: true,
    },
    listType: {
      type: Object,
      required: true,
    },
    config: {
      type: Object,
      required: true,
    },
    readonly: {
      type: Object,
      required: true,
    },
    selected: {
      type: Object,
      required: true,
    },
    setAttr: {
      type: Function,
      required: true,
    },
    onMount: {
      type: Function,
      required: true,
    },
  },
  setup({
    label,
    checked,
    listType,
    config,
    readonly,
    setAttr,
    onMount,
    selected,
  }) {
    const contentWrapperRef: VNodeRef = (div) => {
      if (div == null) return
      if (div instanceof Element) {
        onMount(div)
      }
    }

    const onClickLabel = (e: Event) => {
      e.stopPropagation()
      e.preventDefault()

      // DEBUG: Log checkbox component click
      console.log('[CHECKBOX COMPONENT] onClickLabel triggered, checked=', checked.value)

      if (checked.value == null) return
      setAttr('checked', !checked.value)
    }

    // Prevent ProseMirror from capturing mousedown and focusing the editor
    // This stops input method from being triggered on mobile devices
    const onLabelMouseDown = (e: MouseEvent) => {
      // DEBUG: Log mousedown event
      console.log('[CHECKBOX COMPONENT] onLabelMouseDown triggered')
      e.preventDefault()
    }

    const onLabelKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault()
        e.stopPropagation()
        if (checked.value != null) {
          setAttr('checked', !checked.value)
        }
      }
    }

    const icon = computed(() => {
      return config.renderLabel({
        label: label.value,
        listType: listType.value,
        checked: checked.value,
        readonly: readonly.value,
      })
    })

    const labelClass = computed(() => {
      if (checked.value == null) {
        if (listType.value === 'bullet') return 'bullet'
        return 'ordered'
      }

      if (checked.value) return 'checked'
      return 'unchecked'
    })

    return () => {
      const isCheckbox = checked.value != null
      return (
        <li
          class={clsx(
            'list-item',
            selected.value && 'ProseMirror-selectednode'
          )}
        >
          <div
            class="label-wrapper"
            onClick={onClickLabel}
            onMousedown={isCheckbox ? onLabelMouseDown : undefined}
            onKeydown={isCheckbox ? onLabelKeyDown : undefined}
            contenteditable={false}
            tabindex={isCheckbox ? 0 : undefined}
            role={isCheckbox ? 'checkbox' : undefined}
            aria-checked={isCheckbox ? checked.value : undefined}
            style={{ userSelect: 'none' }}
          >
            <Icon
              class={clsx(
                'label',
                readonly.value && 'readonly',
                labelClass.value
              )}
              icon={icon.value}
            />
          </div>
          <div class="children" ref={contentWrapperRef} />
        </li>
      )
    }
  },
})

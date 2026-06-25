import { defineComponent, ref, type Ref, h } from 'vue'

import type { LinkTooltipConfig } from '../slices'

import { Icon } from '../../__internal__/components/icon'
import { keepAlive } from '../../__internal__/keep-alive'

keepAlive(h)

type PreviewLinkProps = {
  config: Ref<LinkTooltipConfig>
  src: Ref<string>
  onEdit: Ref<() => void>
  onRemove: Ref<() => void>
}

export const PreviewLink = defineComponent<PreviewLinkProps>({
  props: {
    config: {
      type: Object,
      required: true,
    },
    src: {
      type: Object,
      required: true,
    },
    onEdit: {
      type: Object,
      required: true,
    },
    onRemove: {
      type: Object,
      required: true,
    },
  },
  setup({ config, src, onEdit, onRemove }) {
    const copied = ref(false)
    let copyTimer: number | undefined

    const onClickEditButton = (e: Event) => {
      e.preventDefault()
      e.stopPropagation()
      onEdit.value()
    }

    const onClickRemoveButton = (e: Event) => {
      e.preventDefault()
      e.stopPropagation()
      onRemove.value()
    }

    const onClickPreview = (e: Event) => {
      e.preventDefault()
      const link = src.value
      if (navigator.clipboard && link) {
        navigator.clipboard
          .writeText(link)
          .then(() => {
            copied.value = true
            if (copyTimer) window.clearTimeout(copyTimer)
            copyTimer = window.setTimeout(() => {
              copied.value = false
            }, 2000)
            config.value.onCopyLink(link)
          })
          .catch((e) => console.error(e))
      }
    }

    return () => {
      return (
        <div class="link-preview">
          <Icon
            class={`button link-icon ${copied.value ? 'copied' : ''}`}
            icon={copied.value ? '✓' : config.value.linkIcon}
            onClick={onClickPreview}
            title={copied.value ? '已复制!' : '点击复制链接'}
          />
          <a href={src.value} target="_blank" class="link-display">
            {src.value}
          </a>
          <Icon
            class="button link-edit-button"
            icon={config.value.editButton}
            onClick={onClickEditButton}
          />
          <Icon
            class="button link-remove-button"
            icon={config.value.removeButton}
            onClick={onClickRemoveButton}
          />
        </div>
      )
    }
  },
})

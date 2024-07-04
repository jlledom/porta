const useScript = (url: string, cb: (ev: Event) => void): void => {
  const script = document.createElement('script')

  script.src = url
  script.async = true
  script.addEventListener('load', cb)

  document.body.appendChild(script)
}

export { useScript }

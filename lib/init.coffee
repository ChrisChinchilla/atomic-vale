path = require 'path'
process = require 'child_process'

{CompositeDisposable, project} = require 'atom'

module.exports =
  config:
    valePath:
      type: 'string'
      title: 'Path to your vale installation'
      default: 'vale'

    configPath:
      type: 'string'
      title: 'Path to your vale configuation file'
      default: atom.project.getPaths()[0]

  activate: =>
    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.config.observe 'atomic-vale.valePath',
        (valePath) =>
          @valePath = valePath

    @subscriptions.add atom.config.observe 'atomic-vale.configPath',
      (configPath) =>
        @configPath = configPath

  deactivate: =>
      @subscriptions.dispose()

  provideLinter: =>
    provider =
      name: 'vale'

      grammarScopes: [
        "source.gfm"
        "gfm.restructuredtext"
        "source.asciidoc"
        "text.md"
        "text.git-commit"
        "text.plain"
        "text.plain.null-grammar"
        "text.restructuredtext"
        "text.bibtex"
        "text.tex.latex"
        "text.tex.latex.beamer"
        "text.log.latex"
        "text.tex.latex.memoir"
        "text.tex"
      ]

      scope: 'file'

      lint: (textEditor) =>
        filePath = textEditor.getPath()
        output = "{}"
        config = "{}"

        runLinter = (jsonConfig, resolve) =>
          onError = ({error,handle}) =>
            atom.notifications.addError "Error running #{@valePath}",
              detail: "#{error.message}"
              dismissable: true
            handle()
            return []

          lintProcess = process.spawn @valePath,
            ['--output=JSON', filePath],
            cwd: @configPath

          lintProcess.stdout.on 'data', (data) =>
            output = data.toString()
            if output.length <= 3 # if empty object
              output = '{"__filePath__":[]}'.replace('__filePath__', filePath)

            feedback = JSON.parse(output)[filePath]
            messages = []
            for message in feedback
              atomMessageLine = message.Line - 1
              messages.push
                type: message.Severity
                text: message.Message
                filePath: filePath
                range: [
                  [atomMessageLine, message.Span[0]]
                  [atomMessageLine, message.Span[1]]
                ]

            resolve messages

          lintProcess.stdout.on 'error', (error, handle) => onError

        return new Promise (resolve, reject) =>
          getConfigProcess=process.spawn @valePath,
            ['dump-config'],
            cwd: @configPath

          getConfigProcess.stdout.on 'data', (data) => runLinter(data.toString(), resolve)

          getConfigProcess.stdout.on 'error', (error, handle) => onError
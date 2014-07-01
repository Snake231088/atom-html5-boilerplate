module.exports =
  activate: ->
    atom.workspaceView.command "atom-html5-boilerplate:toggle", => @toggle()

  toggle: ->
    {BufferedProcess} = require 'atom'

    command = 'curl'
    args = ['https://api.github.com/repos/h5bp/html5-boilerplate/releases']

    json_str = ''

    stdout = (output) ->
      json_str += output

    exit = (code) ->
      if code
        console.error "curl exited with #{code}"
        return
      else
        json = JSON.parse json_str

        if json
          max         = undefined
          max_date    = new Date "0"

          for rel in json
            d = new Date rel.created_at
            if d > max_date
              max_date    = d
              max         = rel

          if max
            #ok i've the latest release version

            https      = require 'https'
            fs         = require 'fs'
            p          = atom.project.getPath()
            filename   = p + "/" + max.tag_name + ".tar.gz"

            options    =
              host: 'codeload.github.com'
              method: 'GET'
              path: '/h5bp/html5-boilerplate/tar.gz/' + max.tag_name

            https.get options, (res) ->
              res.setEncoding 'binary'
              data     = ''
              res.on 'data', (chunk) ->
                data   += chunk.toString()
              res.on 'end', () ->
                fs.writeFile filename, data, 'binary', (error) ->
                  console.error("Error writing file", error) if error
                  return

                # Unzip
                tar      = require './tar/tar.js'
                zlib     = require 'zlib'

                fs.createReadStream(filename)
                  .on "error", (error) ->
                    console.error("Extract error: ", error)
                    return
                  .pipe zlib.Unzip()
                  .pipe tar.Extract { path: p }
                  .on "end", () ->
                    # Move
                    path        = require 'path'
                    foldername  = max.tag_name.replace 'v', ''
                    base        = p + "/html5-boilerplate-" + foldername
                    files       = []
                    getDirs = (basedir, subdir) ->
                      tmp = fs.readdirSync basedir
                      for file in tmp
                        filePath = "#{basedir}/#{file}"
                        stat = fs.statSync(filePath)

                        if stat.isDirectory()
                          getDirs filePath, "#{subdir}#{file}/"
                        else
                          files.push "#{subdir}#{file}"

                      return files

                    files = getDirs base, ""
                    for file in files
                      if !fs.existsSync "#{p}/" + path.dirname "#{file}"
                        fs.mkdirSync "#{p}/" + path.dirname "#{file}"
                      fs.renameSync "#{base}/#{file}", "#{p}/#{file}"

                    #Remove file and folders
                    deleteFolderRecursive = (path) ->
                      if fs.existsSync(path)
                        for file in fs.readdirSync(path)
                          curPath = path + "/" + file
                          if fs.lstatSync(curPath).isDirectory()
                            deleteFolderRecursive curPath
                          else
                            fs.unlinkSync curPath
                        fs.rmdirSync path

                    deleteFolderRecursive base

                    fs.unlinkSync filename


            return

        console.error 'unknown error'

    viewRelease = new BufferedProcess({command, args, stdout, exit})

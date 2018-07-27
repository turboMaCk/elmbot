import {RTMClient} from '@slack/client';
import Elm from '../elm/Main.elm';
import Repl from 'node-elm-repl';
import tmp from 'tmp';
import fs from 'fs';
import childProcess from 'child_process';
import he from 'he';
import rimraf from 'rimraf';
import ncp from 'ncp';

const config = JSON.parse(fs.readFileSync('config/config.json', 'utf8'));

const rtm = new RTMClient(config.apiToken);
const app = Elm.Main.worker();

app.ports.start.subscribe(
  () => rtm.start()
);

app.ports.sendMessage.subscribe(
  ({text, channel}) => rtm.sendMessage(text, channel)
);

const createElmPackageJson = (dirName) => {
  try {
    childProcess.spawnSync('elm-make', ['--yes'], {cwd: dirName});
  }
  catch (e) {
    app.ports.getResultRaw.send({channel, type: "other_error", error: "Couldn't create elm-package.json! (ask @janiczek about it)"});
  }
};

const installPackages = (packages, dirName) => {
  console.log('installing packages');
  let failedPackage = null;
  packages.forEach((pkg) => {
      if (failedPackage) return;
      const result = childProcess.spawnSync('elm-package', ['install', '--yes', pkg], {cwd: dirName});
      if (result.status === 1) {
        failedPackage = pkg;
      } else {
      }
  });
  if (!failedPackage) {
  }
  return failedPackage;
};

const cleanup = (dirName) => {
  rimraf(dirName, (err) => {
      if (err) {
        app.ports.getResultRaw.send({channel, type: "other_error", error: "Couldn't delete the temp directory! (ask @janiczek about it)"});
      }
  });
};

const prepareTemplateDirectory = () => {
  console.log('preparing template directory (compiling elm-lang/core and stuff)');
  const tempDir = tmp.dirSync({prefix: 'elmbot_template_'});
  createElmPackageJson(tempDir.name);
  return tempDir.name;
};

const templateDir = prepareTemplateDirectory();

const copyTemplateToSnippet = (templateDir, snippetDir, channel) =>  {
  console.log('copying template folder to a snippet folder');
  return new Promise(function(resolve, reject) {
    ncp(templateDir, snippetDir, (err) => {
        if (err) {
          app.ports.getResultRaw.send({channel, type: "other_error", error: "Couldn't copy template directory to a temporary one for your snippet! (ask @janiczek about it)"});
          reject();
        }
        resolve();
    });
  });
}

app.ports.eval.subscribe(
  ({channel, packages, imports, expressions}) => {

    if (expressions.length === 0) {
      app.ports.getResultRaw.send({channel, type: "error_no_expressions"});
      return;
    }

    const decodedExpressions = expressions.map(he.decode);
    
    console.log({packages, imports, decodedExpressions});

    const snippetDir = tmp.dirSync({prefix: 'elmbot_snippet_'}).name;

    copyTemplateToSnippet(templateDir, snippetDir, channel)
    .then(() => {

        const failedPackage = installPackages(packages, snippetDir);
        if (failedPackage) {
          app.ports.getResultRaw.send({channel, type: "error_installing_package", error: failedPackage});
          return;
        };

        console.log('running the code');
        new Repl({ workDir: snippetDir })
        .getValues(imports, decodedExpressions)
        .then((values) => {
            console.log('done! sending');
            app.ports.getResultRaw.send({channel, type: "result", result: values[values.length - 1]});
            cleanup(snippetDir);
        })
        .catch((err) => {
            console.log('error running the code');
            app.ports.getResultRaw.send({channel, type: "error_running_code", error: err.stderr.toString()});
            cleanup(snippetDir);
        });

    });

  }
);

rtm.on('message',
  message => app.ports.incomingMessageRaw.send(message)
);

rtm.on('hello',
  message => app.ports.isRunning.send(true)
);

rtm.on('goodbye',
  message => app.ports.isRunning.send(false)
);

const clearAllTempFolders = () => {
  rimraf('/tmp/elmbot_snippet_*', (err) => {if (err) {console.log(err);}});
  rimraf('/tmp/elmbot_template_*', (err) => {if (err) {console.log(err);}});
};

process.on('exit', () => {
    clearAllTempFolders();
});

process.on('SIGINT', function() {
    clearAllTempFolders();
    process.exit();
});


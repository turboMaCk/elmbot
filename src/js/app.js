import {RTMClient} from '@slack/client';
import Elm from '../elm/Main.elm';
import Repl from 'node-elm-repl';
import tmp from 'tmp';
import fs from 'fs';
import childProcess from 'child_process';
import he from 'he';
import rimraf from 'rimraf';

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

app.ports.eval.subscribe(
  ({channel, packages, imports, expressions}) => {

    if (expressions.length === 0) {
      app.ports.getResultRaw.send({channel, type: "error_no_expressions"});
      return;
    }

    const decodedExpressions = expressions.map(he.decode);
    
    console.log({packages, imports, decodedExpressions});

    const tempDir = tmp.dirSync({prefix: 'snippet_'});

    createElmPackageJson(tempDir.name);

    const failedPackage = installPackages(packages, tempDir.name);
    if (failedPackage) {
        app.ports.getResultRaw.send({channel, type: "error_installing_package", error: failedPackage});
        return;
    };

    new Repl({ workDir: tempDir.name })
      .getValues(imports, decodedExpressions)
      .then((values) => {
          app.ports.getResultRaw.send({channel, type: "result", result: values[values.length - 1]});
          cleanup(tempDir.name);
      })
      .catch((err) => {
          app.ports.getResultRaw.send({channel, type: "error_running_code", error: err.stderr.toString()});
          cleanup(tempDir.name);
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

process.on('SIGINT', function() {
    process.exit();
});

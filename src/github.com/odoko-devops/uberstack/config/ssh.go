package config

import (
	"golang.org/x/crypto/ssh"
	"io/ioutil"
	"os/user"
    "bufio"
    "log"
    "io"
	"fmt"
)

func getKeyFile() (key ssh.Signer, err error){
    usr, _ := user.Current()
    file := usr.HomeDir + "/.ssh/id_rsa"
    buf, err := ioutil.ReadFile(file)
    if err != nil {
        return
    }
    key, err = ssh.ParsePrivateKey(buf)
    if err != nil {
        return
     }
    return
}

func watchOutputStream(typ string, r bufio.Reader) {
	for {
		line, _, err := r.ReadLine()
		if err == io.EOF {
			break
		}
		log.Printf("%s: %s\n", typ, line)
	}
}

func executeBySSH(hostName, user string, signer ssh.Signer, command string) error {
	config := &ssh.ClientConfig{
		User: user,
		Auth: []ssh.AuthMethod{
			ssh.PublicKeys(signer),
		},
	}

	log.Printf("Connecting to %s as %s", hostName, user)
	client, err := ssh.Dial("tcp", hostName + ":22", config)
	if err != nil {
		return err
	}

	session, err := client.NewSession()
	if err != nil {
		return err
	}
	defer session.Close()

	stdout, _ := session.StdoutPipe()
	stderr, _ := session.StderrPipe()
	stdOutReader := bufio.NewReader(stdout)
	stdErrReader := bufio.NewReader(stderr)
	go watchOutputStream("stdout", *stdOutReader)
	go watchOutputStream("stderr", *stdErrReader)

	if err := session.Start(command); err != nil {
		return err
	}
	err = session.Wait()
	return err
}

func uploadViaSCP(hostName, user string, signer ssh.Signer, input, destination string) error {
	config := &ssh.ClientConfig{
		User: user,
		Auth: []ssh.AuthMethod{
			ssh.PublicKeys(signer),
		},
	}

	log.Printf("Connecting to %s as %s", hostName, user)
	client, err := ssh.Dial("tcp", hostName + ":22", config)
	if err != nil {
		return err
	}

	session, err := client.NewSession()
	if err != nil {
		return err
	}
	defer session.Close()

	go func() {
		w, _ := session.StdinPipe()
		defer w.Close()
		fmt.Fprintln(w, input)
	}()

	stdout, _ := session.StdoutPipe()
	stderr, _ := session.StderrPipe()
	stdOutReader := bufio.NewReader(stdout)
	stdErrReader := bufio.NewReader(stderr)
	go watchOutputStream("stdout", *stdOutReader)
	go watchOutputStream("stderr", *stdErrReader)

	command := fmt.Sprintf("tee %s", destination)
	if err := session.Start(command); err != nil {
		return err
	}
	err = session.Wait()
	return err
}
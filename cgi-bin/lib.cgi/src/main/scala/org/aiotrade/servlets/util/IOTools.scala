/*
 * DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
 *
 * Copyright 1997-2008 Sun Microsystems, Inc. All rights reserved.
 *
 * The contents of this file are subject to the terms of either the GNU
 * General Public License Version 2 only ("GPL") or the Common Development
 * and Distribution License("CDDL") (collectively, the "License").  You
 * may not use this file except in compliance with the License. You can obtain
 * a copy of the License at https://glassfish.dev.java.net/public/CDDL+GPL.html
 * or glassfish/bootstrap/legal/LICENSE.txt.  See the License for the specific
 * language governing permissions and limitations under the License.
 *
 * When distributing the software, include this License Header Notice in each
 * file and include the License file at glassfish/bootstrap/legal/LICENSE.txt.
 * Sun designates this particular file as subject to the "Classpath" exception
 * as provided by Sun in the GPL Version 2 section of the License file that
 * accompanied this code.  If applicable, add the following below the License
 * Header, with the fields enclosed by brackets [] replaced by your own
 * identifying information: "Portions Copyrighted [year]
 * [name of copyright owner]"
 *
 * Contributor(s):
 *
 * If you wish your version of this file to be governed by only the CDDL or
 * only the GPL Version 2, indicate your decision by adding "[Contributor]
 * elects to include this software in this distribution under the [CDDL or GPL
 * Version 2] license."  If you don't indicate a single choice of license, a
 * recipient has the option to distribute your version of this file under
 * either the CDDL, the GPL Version 2 or to extend the choice of license to
 * its licensees as provided above.  However, if you add GPL Version 2 code
 * and therefore, elected the GPL Version 2 license, then the option applies
 * only if the new code is made subject to such option by the copyright
 * holder.
 *
 *
 * This file incorporates work covered by the following copyright and
 * permission notice:
 *
 * Copyright 2004 The Apache Software Foundation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package org.aiotrade.servlets.util

import java.io.InputStream
import java.io.IOException
import java.io.OutputStream
import java.io.Reader
import java.io.Writer

/**
 * Contains commonly needed I/O-related methods
 *
 * @author Dan Sandberg
 */
object IOTools {

  protected val DEFAULT_BUFFER_SIZE = 4 * 1024 //4k

  /**
   * Read input from reader and write it to writer until there is no more
   * input from reader.
   *
   * @param reader the reader to read from.
   * @param writer the writer to write to.
   * @param buf the char array to use as a bufferx
   */
  def flow(reader: Reader, writer: Writer, buf: Array[Char]) {
    var numRead = 0
    while ({numRead = reader.read(buf); numRead >= 0}) {
      writer.write(buf, 0, numRead)
    }
  }

  /**
   * @see flow( Reader, Writer, char[] )
   */
  @throws(classOf[IOException])
  def flow(reader: Reader, writer: Writer) {
    val buf = new Array[Char](DEFAULT_BUFFER_SIZE)
    flow(reader, writer, buf)
  }

  /**
   * Read input from input stream and write it to output stream
   * until there is no more input from input stream.
   *
   * @param input stream the input stream to read from.
   * @param output stream the output stream to write to.
   * @param buf the byte array to use as a buffer
   */
  @throws(classOf[IOException])
  def flow(is: InputStream, os: OutputStream, buf: Array[Byte]) {
    var numRead = 0
    while ({numRead = is.read(buf); numRead >= 0}) {
      os.write(buf, 0, numRead)
    }
  }

  /**
   * @see flow( Reader, Writer, Array[Byte] )
   */
  @throws(classOf[IOException])
  def flow(is: InputStream, os: OutputStream) {
    val buf = new Array[Byte](DEFAULT_BUFFER_SIZE)
    flow(is, os, buf)
  }
}